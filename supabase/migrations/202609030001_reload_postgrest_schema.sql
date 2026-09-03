-- Make newly deployed Miloom RPCs immediately visible to PostgREST clients.
notify pgrst, 'reload schema';
