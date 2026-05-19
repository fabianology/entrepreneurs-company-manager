document.addEventListener('DOMContentLoaded', () => {
    // Form submission handling
    const form = document.getElementById('waitlist-form');
    const messageEl = document.getElementById('form-message');
    
    if (form) {
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            const email = document.getElementById('email').value;
            
            if (email) {
                // Simulate API call
                const submitBtn = form.querySelector('button[type="submit"]');
                const originalText = submitBtn.textContent;
                submitBtn.textContent = 'Joining...';
                submitBtn.disabled = true;
                
                setTimeout(() => {
                    messageEl.textContent = "You're on the list! Keep an eye on your inbox.";
                    messageEl.className = 'form-message success-text';
                    form.reset();
                    submitBtn.textContent = originalText;
                    submitBtn.disabled = false;
                    
                    // Clear message after 5 seconds
                    setTimeout(() => {
                        messageEl.textContent = '';
                    }, 5000);
                }, 1000);
            }
        });
    }

    // Scroll animation for features
    const observerOptions = {
        threshold: 0.1,
        rootMargin: "0px 0px -50px 0px"
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = "1";
                entry.target.style.transform = "translateY(0)";
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Initial setup for feature cards
    const featureCards = document.querySelectorAll('.feature-card');
    featureCards.forEach((card, index) => {
        card.style.opacity = "0";
        card.style.transform = "translateY(30px)";
        card.style.transition = `all 0.6s ease ${index * 0.1}s`;
        observer.observe(card);
    });
});
