import Foundation

// MARK: - InteractiveBrowserView Dark Mode Extension
// Extracted from InteractiveBrowserView.swift following Apple engineering standards
// File size: ~135 lines (under Apple's 300 line "excellent" threshold)

extension InteractiveBrowserView {
    static let darkModeCSS = """
        /* Night Eye Style Dark Mode - Simple Inversion with Smart Image Handling */

        /* Apply filter to root, which inverts the entire page */
        html {
            background-color: #fff !important;
            filter: invert(90%) hue-rotate(180deg) !important;
        }

        /* Images: use screen blend mode to eliminate dark backgrounds (which were white before inversion) */
        img {
            mix-blend-mode: screen !important;
        }

        /* Counter-invert photos/content images to preserve their colors */
        img[src*="photo"], img[src*="image"], img[src*="upload"],
        img[src*="avatar"], img[src*="profile"], img[src*="thumb"],
        img[src*="content"] {
            filter: invert(90%) hue-rotate(180deg) !important;
            mix-blend-mode: normal !important;
        }

        /* Videos and iframes should be counter-inverted to look normal */
        video, canvas, iframe {
            filter: invert(90%) hue-rotate(180deg) !important;
        }

        /* Scrollbars */
        ::-webkit-scrollbar {
            filter: invert(90%) hue-rotate(180deg);
        }
    """

    static let darkModeScript = """
        (function() {
            'use strict';

            // Inject dark mode stylesheet
            const style = document.createElement('style');
            style.id = 'swag-dark-mode';
            style.textContent = `\(darkModeCSS)`;

            if (document.head) {
                document.head.appendChild(style);
            } else {
                document.addEventListener('DOMContentLoaded', () => {
                    if (document.head && !document.getElementById('swag-dark-mode')) {
                        document.head.appendChild(style);
                    }
                });
            }

            // Fix image container backgrounds (removes white boxes around logos)
            function fixImageContainers() {
                // Find all images
                const images = document.querySelectorAll('img');

                images.forEach(img => {
                    // Force transparent background on the image itself
                    img.style.backgroundColor = 'transparent';

                    // Get the parent element
                    let parent = img.parentElement;

                    // Check up to 5 levels of parents and force transparent backgrounds
                    for (let i = 0; i < 5 && parent; i++) {
                        // Force transparent on ANY parent container with a background
                        const computedBg = window.getComputedStyle(parent).backgroundColor;

                        if (computedBg && computedBg !== 'rgba(0, 0, 0, 0)' && computedBg !== 'transparent') {
                            // Force transparent background
                            parent.style.setProperty('background-color', 'transparent', 'important');
                            parent.style.setProperty('background', 'transparent', 'important');
                        }

                        // Also remove inline style backgrounds
                        if (parent.style.backgroundColor || parent.style.background) {
                            parent.style.setProperty('background-color', 'transparent', 'important');
                            parent.style.setProperty('background', 'transparent', 'important');
                        }

                        parent = parent.parentElement;
                    }
                });
            }

            // Run after DOM loads
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => {
                    setTimeout(fixImageContainers, 100);
                    setTimeout(fixImageContainers, 500);
                });
            } else {
                setTimeout(fixImageContainers, 100);
                setTimeout(fixImageContainers, 500);
            }

            // Watch for new images being added
            const observer = new MutationObserver((mutations) => {
                let hasNewImages = false;
                mutations.forEach(mutation => {
                    if (mutation.addedNodes.length > 0) {
                        mutation.addedNodes.forEach(node => {
                            if (node.nodeType === 1 && (node.tagName === 'IMG' || node.querySelector('img'))) {
                                hasNewImages = true;
                            }
                        });
                    }
                });

                if (hasNewImages) {
                    setTimeout(fixImageContainers, 100);
                }
            });

            if (document.body) {
                observer.observe(document.body, {
                    childList: true,
                    subtree: true
                });
            }
        })();
    """

    static let removeDarkModeScript = """
        (function() {
            const style = document.getElementById('swag-dark-mode');
            if (style) {
                style.remove();
            }
            document.querySelectorAll('[style*="--bg-color"]').forEach(el => {
                el.style.removeProperty('--bg-color');
            });
        })();
    """
}
