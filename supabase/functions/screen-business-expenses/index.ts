import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/http.ts";
import { processBusinessExpenseJob } from "../_shared/business_expense_ai.ts";

Deno.serve(async req => {
  if(req.method==="OPTIONS") return new Response("ok",{headers:corsHeaders});
  if(req.method!=="POST") return json({error:"Method not allowed"},405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i,"");
  const cronSecret = Deno.env.get("CRON_SECRET");
  const isCron = !!cronSecret && req.headers.get("x-cron-secret") === cronSecret;
  if(!token && !isCron) return json({error:"Unauthorized"},401);
  const admin = createClient(url,serviceKey,{auth:{persistSession:false}});
  try {
    if(token===serviceKey || isCron) {
      // Called by the existing server scheduler. Never accept user_id from callers.
      await admin.rpc("queue_orphan_business_expense_files");
      const {data:cleanup} = await admin.from("business_expense_file_cleanup").select("id,path").order("created_at").limit(25);
      for(const file of cleanup ?? []) {
        const {error:removeError} = await admin.storage.from("CompanyDocuments").remove([file.path]);
        if(!removeError) await admin.from("business_expense_file_cleanup").delete().eq("id",file.id);
      }
      const {error:enqueueError} = await admin.rpc("enqueue_due_business_expense_scans");
      if(enqueueError) throw enqueueError;
      const {data:jobs,error} = await admin.from("business_expense_jobs").select("id").in("state",["queued","running"]).or(`lease_until.is.null,lease_until.lt.${new Date().toISOString()}`).order("updated_at").limit(4);
      if(error) throw error;
      return json({results:await Promise.all((jobs ?? []).map(j=>processBusinessExpenseJob(admin,j.id)))});
    }
    const {data:{user},error:authError} = await admin.auth.getUser(token);
    if(authError || !user) return json({error:"Unauthorized"},401);
    const body = await req.json();
    if(typeof body.job_id!=="string" || !/^[0-9a-f-]{36}$/i.test(body.job_id)) return json({error:"Invalid job"},400);
    const {data:job,error} = await admin.from("business_expense_jobs").select("id").eq("id",body.job_id).eq("user_id",user.id).maybeSingle();
    if(error) throw error;
    if(!job) return json({error:"Job not found"},404);
    return json(await processBusinessExpenseJob(admin,job.id));
  } catch { return json({error:"Could not process screening. Saved reviews are unchanged."},500); }
});
