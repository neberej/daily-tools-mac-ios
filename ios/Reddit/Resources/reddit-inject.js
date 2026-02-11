// reddit-inject.js — One-pass DOM cleanup at document-end, main-frame only.
// No MutationObservers, no continuous DOM churn.

(function() {
    'use strict';

    // ===== REMOVE UNWANTED ELEMENTS (one pass) =====
    var selectorsToRemove = [
        '.side', '.sidebar', '#header', '.footer-parent', '.footer',
        '.bottommenu', '.debuginfo', '.premium-banner-outer', '.listing-chooser',
        '.organic-listing', '.promotedlink', '.sponsorshipbox',
        '.ad-container', '.ad_main', '.goldvertisement',
        '.login-form-side', '.submit-text', '.morelink',
        '.sr-bar', '.tabmenu', '.awardings-bar',
        // Mobile / app banners
        '.mobile-web-redirect-bar', '#mobile-redirect-bar', '.mobile-web-redirect',
        '.mobile-banner', '.xpromo-overlay', '.xpromo-modal',
        '.xpromo-listing', '.xpromo-list-item', '.xpromo-display-bar',
        '.interstitial-wrapper', '.app-banner', '.native-app-banner',
        '.infobar-toaster', '.listingsignupbar', '.commentsignupbar',
        '.below-search-bar-toaster', '.loginpopup',
        // Vote columns (read-only)
        '.midcol', '.midcol-unvoted',
        // Flairs (badge elements only, not post containers)
        '.flair', '.flair-text', '.linkflairlabel', '.linkflair-text'
    ];

    selectorsToRemove.forEach(function(sel) {
        document.querySelectorAll(sel).forEach(function(el) { el.remove(); });
    });

    // Remove promoted posts
    document.querySelectorAll('.link').forEach(function(link) {
        if (link.classList.contains('promotedlink') || link.classList.contains('promoted')) {
            link.remove();
        }
    });

    // Remove subreddit custom stylesheets (one pass, no observer)
    document.querySelectorAll('link[rel="stylesheet"]').forEach(function(el) {
        var href = (el.href || '').toLowerCase();
        if (href.indexOf('redditstatic.com') === -1) el.remove();
    });
    document.querySelectorAll('style').forEach(function(el) {
        if (el.id === 'reddit-inject-css') return; // preserve our own injected styles
        var text = el.textContent || '';
        if (text.length > 300) el.remove();
    });

    // Remove vote arrows
    document.querySelectorAll('.arrow').forEach(function(el) { el.remove(); });

    // Remove flair spans inside comments/taglines
    document.querySelectorAll('span[class*="flair"]').forEach(function(el) { el.remove(); });

    // Strip action links: keep only comments count on link listings
    document.querySelectorAll('.link .flat-list').forEach(function(list) {
        var items = list.querySelectorAll('li');
        for (var i = 1; i < items.length; i++) items[i].remove();
    });

    // Strip all action links on comments
    document.querySelectorAll('.comment .flat-list').forEach(function(list) {
        list.remove();
    });

    // Remove background images from subreddit headers
    document.querySelectorAll('[style*="background-image"]').forEach(function(el) {
        el.style.backgroundImage = 'none';
    });

    // Fix content width
    var content = document.querySelector('.content[role="main"]');
    if (content) {
        content.style.margin = '0';
        content.style.padding = '8px';
        content.style.maxWidth = '100%';
    }

    // ===== FLOATING NAVIGATION BUTTONS =====
    // Inline styles guarantee position:fixed even if CSS is stripped or delayed.
    var floatContainerStyle = 'position:fixed!important;bottom:32px!important;z-index:99999!important;display:flex!important;flex-direction:column!important;gap:10px!important;pointer-events:auto!important;';
    var floatBtnStyle = 'width:44px!important;height:44px!important;border-radius:50%!important;border:0.5px solid rgba(255,255,255,0.2)!important;background:rgba(30,30,40,0.85)!important;-webkit-backdrop-filter:blur(20px)!important;backdrop-filter:blur(20px)!important;color:#fff!important;font-size:20px!important;display:flex!important;align-items:center!important;justify-content:center!important;cursor:pointer!important;box-shadow:0 4px 12px rgba(0,0,0,0.3)!important;-webkit-tap-highlight-color:transparent!important;padding:0!important;min-height:44px!important;line-height:1!important;';

    if (!document.getElementById('rn-float-container')) {
        // Right side: scroll-to-top + next-item
        var container = document.createElement('div');
        container.id = 'rn-float-container';
        container.setAttribute('style', floatContainerStyle + 'right:16px!important;');

        var topBtn = document.createElement('button');
        topBtn.setAttribute('style', floatBtnStyle);
        topBtn.innerHTML = '&#8593;';
        topBtn.onclick = function(e) {
            e.preventDefault(); e.stopPropagation();
            window.scrollTo({ top: 0, behavior: 'smooth' });
        };

        var nextBtn = document.createElement('button');
        nextBtn.setAttribute('style', floatBtnStyle);
        nextBtn.innerHTML = '&#8595;';
        nextBtn.onclick = function(e) {
            e.preventDefault(); e.stopPropagation();
            var isComments = !!document.querySelector('.commentarea');
            var targets = isComments
                ? document.querySelectorAll('.commentarea > .sitetable > .thing.comment')
                : document.querySelectorAll('.link.thing, .link');
            if (targets.length === 0 && isComments) {
                targets = document.querySelectorAll('.comment');
            }
            for (var i = 0; i < targets.length; i++) {
                if (targets[i].getBoundingClientRect().top > 80) {
                    targets[i].scrollIntoView({ behavior: 'smooth', block: 'start' });
                    return;
                }
            }
            if (targets.length > 0) targets[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
        };

        container.appendChild(topBtn);
        container.appendChild(nextBtn);
        document.body.appendChild(container);
    }
})();
