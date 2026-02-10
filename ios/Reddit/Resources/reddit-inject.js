// reddit-inject.js — DOM cleanup, mobile optimizations, and floating nav for old.reddit.com

(function() {
    'use strict';

    // ===== REMOVE UNWANTED ELEMENTS =====
    var selectorsToRemove = [
        '.side',
        '.sidebar',
        '#header',
        '.footer-parent',
        '.footer',
        '.bottommenu',
        '.debuginfo',
        '.premium-banner-outer',
        '.listing-chooser',
        '.organic-listing',
        '.promotedlink',
        '.sponsorshipbox',
        '.ad-container',
        '.ad_main',
        '.goldvertisement',
        '.infobar',
        '.login-form-side',
        '.submit-text',
        '.morelink',
        '.sr-bar',
        '.tabmenu',
        '.awardings-bar',
        // Mobile / app banners
        '.mobile-web-redirect-bar',
        '#mobile-redirect-bar',
        '.mobile-web-redirect',
        '.mobile-banner',
        '.xpromo-overlay',
        '.xpromo-modal',
        '.xpromo-listing',
        '.xpromo-list-item',
        '.xpromo-display-bar',
        '.interstitial-wrapper',
        '.app-banner',
        '.native-app-banner',
        '.infobar-toaster',
        '.listingsignupbar',
        '.commentsignupbar',
        '.below-search-bar-toaster',
        '.loginpopup',
        // Vote columns (read-only)
        '.midcol',
        '.midcol-unvoted'
    ];

    selectorsToRemove.forEach(function(selector) {
        document.querySelectorAll(selector).forEach(function(el) {
            el.remove();
        });
    });

    // Remove promoted / ad links
    document.querySelectorAll('.link').forEach(function(link) {
        if (link.classList.contains('promotedlink') ||
            link.classList.contains('promoted') ||
            link.querySelector('.promoted-tag')) {
            link.remove();
        }
    });

    // Aggressively remove ALL subreddit custom stylesheets
    // Keep only: redditstatic.com core CSS and our own injected styles (marked with REDDIT_INJECT_MARKER)
    document.querySelectorAll('link[rel="stylesheet"]').forEach(function(link) {
        var href = (link.href || '').toLowerCase();
        if (href.indexOf('redditstatic.com') === -1) {
            link.remove();
        }
    });
    document.querySelectorAll('style').forEach(function(style) {
        var text = style.textContent || '';
        // Keep our own styles
        if (text.indexOf('REDDIT_INJECT_MARKER') !== -1) return;
        // Keep very small inline styles (likely reddit core)
        if (text.length < 200) return;
        // Everything else is subreddit theme CSS — remove it
        style.remove();
    });

    // Remove any element with inline style that sets a background-image (subreddit banners/headers)
    document.querySelectorAll('#header, #header-img, .pagename, [style*="background-image"]').forEach(function(el) {
        el.style.backgroundImage = 'none';
    });

    // Fix content width
    var content = document.querySelector('.content[role="main"]');
    if (content) {
        content.style.margin = '0';
        content.style.padding = '8px';
        content.style.maxWidth = '100%';
    }

    // Remove vote arrows (read-only mode)
    document.querySelectorAll('.arrow, .midcol .arrow, .midcol, .midcol-unvoted').forEach(function(el) {
        el.remove();
    });

    // Remove flair badges (but NOT parent post containers that have linkflair classes)
    document.querySelectorAll('.flair, .flair-text, .linkflairlabel, .linkflair-text, span[class*="flair"]').forEach(function(el) {
        el.remove();
    });

    // Strip action links: keep only comments count on link listings
    document.querySelectorAll('.link .flat-list').forEach(function(list) {
        var items = list.querySelectorAll('li');
        for (var i = 1; i < items.length; i++) {
            items[i].remove();
        }
    });

    // Strip all action links on comments
    document.querySelectorAll('.comment .flat-list').forEach(function(list) {
        list.remove();
    });

    // Leave panestack-title fully visible so sort dropdown works

    // ===== FLOATING NAVIGATION BUTTONS =====
    // Only add if not already present (re-injection protection)
    if (!document.getElementById('rn-float-container')) {
        // Right side: scroll-to-top + next-item
        var container = document.createElement('div');
        container.id = 'rn-float-container';

        // Scroll-to-top button
        var topBtn = document.createElement('button');
        topBtn.className = 'rn-float-btn';
        topBtn.innerHTML = '&#8593;'; // up arrow
        topBtn.setAttribute('aria-label', 'Scroll to top');
        topBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            window.scrollTo({ top: 0, behavior: 'smooth' });
        });

        // Next top-level item button
        var nextBtn = document.createElement('button');
        nextBtn.className = 'rn-float-btn';
        nextBtn.innerHTML = '&#8595;'; // down arrow
        nextBtn.setAttribute('aria-label', 'Next item');

        nextBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();

            var targets;
            var isCommentPage = !!document.querySelector('.commentarea');

            if (isCommentPage) {
                var topComments = document.querySelectorAll('.commentarea > .sitetable > .thing.comment');
                if (topComments.length === 0) {
                    topComments = document.querySelectorAll('.nestedlisting > .thing.comment');
                }
                if (topComments.length === 0) {
                    topComments = document.querySelectorAll('.comment');
                }
                targets = topComments;
            } else {
                targets = document.querySelectorAll('.link.thing, .link');
            }

            if (targets.length === 0) return;

            var found = false;
            for (var i = 0; i < targets.length; i++) {
                var rect = targets[i].getBoundingClientRect();
                if (rect.top > 80) {
                    targets[i].scrollIntoView({ behavior: 'smooth', block: 'start' });
                    found = true;
                    break;
                }
            }
            if (!found && targets.length > 0) {
                targets[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });

        container.appendChild(topBtn);
        container.appendChild(nextBtn);
        document.body.appendChild(container);

        // Left side: back button (go back in browser history)
        var backContainer = document.createElement('div');
        backContainer.id = 'rn-back-container';
        var backBtn = document.createElement('button');
        backBtn.className = 'rn-float-btn';
        backBtn.innerHTML = '&#8592;'; // left arrow ←
        backBtn.setAttribute('aria-label', 'Go back');
        backBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            if (window.history.length > 1) {
                window.history.back();
            }
        });
        backContainer.appendChild(backBtn);
        document.body.appendChild(backContainer);
    }

    // ===== MUTATION OBSERVER =====
    // Clean dynamically loaded content
    var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                    // Remove ads in dynamically added content
                    if (node.classList && (
                        node.classList.contains('promotedlink') ||
                        node.classList.contains('ad-container') ||
                        node.classList.contains('mobile-web-redirect-bar') ||
                        node.classList.contains('xpromo-overlay') ||
                        node.classList.contains('xpromo-modal') ||
                        node.classList.contains('interstitial-wrapper') ||
                        node.classList.contains('app-banner') ||
                        node.classList.contains('native-app-banner') ||
                        node.classList.contains('listingsignupbar') ||
                        node.classList.contains('loginpopup')
                    )) {
                        node.remove();
                        return;
                    }
                    // Remove arrows, midcol, and flairs from new content
                    if (node.querySelectorAll) {
                        node.querySelectorAll('.arrow, .midcol, .midcol-unvoted, .flair, .flair-text, .linkflairlabel, .linkflair-text, span[class*="flair"]').forEach(function(el) {
                            el.remove();
                        });
                        // Strip action links on new comments
                        node.querySelectorAll('.comment .flat-list').forEach(function(list) {
                            list.remove();
                        });
                        // Strip non-comment action links on new posts
                        node.querySelectorAll('.link .flat-list').forEach(function(list) {
                            var items = list.querySelectorAll('li');
                            for (var i = 1; i < items.length; i++) {
                                items[i].remove();
                            }
                        });
                    }
                }
            });
        });
    });

    if (document.body) {
        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

})();
