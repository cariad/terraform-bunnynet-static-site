# How do I upload my website?

The `cariad/terraform-bunnynet-static-site` module doesn't upload your website. You're responsible for uploading your files to the storage zone, with whichever tool you prefer.

Remember, though, that this module's caching rules are [highly-opinionated](opinions.md) and strict, so there are some rules to follow.

## Fingerprint your long-cached files

Files named `*.avif`, `*.css`, `*.gif`, `*.jpeg`, `*.jpg`, `*.js`, `*.mjs`, `*.mp3`, `*.mp4`, `*.otf`, `*.pdf`, `*.png`, `*.svg`, `*.ttf`, `*.wasm`, `*.webm`, `*.webp`, `*.woff` and `*.woff2` are cached in the CDN and the browser for a year, so you *must* make sure their filename changes if their content changes.

For example, if you build your site with [Hugo](https://gohugo.io/) then [fingerprinting](https://gohugo.io/functions/resources/fingerprint/) your `main.css` file will cause it to be built as something like `main.99ed01e277b426d2d1103c0a04b80e4fa8824f39f1ee453e91511165fb184548.css`. If the content ever changes, then the hash changes too.

!!! info "Extensions must be lowercase"

    A file named `IMG_0001.JPG`, for example, is cached for only five minutes.

!!! warning "Service worker scripts are the exception"

    The only files that you can't fingerprint are JavaScript service worker scripts, if your site has them. See [Service worker scripts](#service-worker-scripts) to learn how to deploy those.

### What if I don't fingerprint them?

Visitors might see older versions of your files.

For example, if you publish `cover.webp`, then edit it and upload it again with the same filename, then visitors who hit a CDN node that already cached the previous file will still see that old file. Returning visitors who already have the file in their browser's cache won't get the new version, either.

### Deleting previous versions

If you need to delete the previous version of a fingerprinted file, don't do it straight after `*.html` and other pages have been uploaded.

Pages cached at the edge or by a service worker can be more than five minutes old, and might still be referring to those previous versions. Give them a chance to expire, otherwise visitors might see broken media links.

Even when you do delete a fingerprinted file, the CDN can keep serving it for up to a year, so purge it in the bunny.net dashboard if it has to be gone sooner.

## Add a 404 page

Upload your custom 404 page as `/404.html`, otherwise visitors will see bunny.net's default 404 page.

## Upload in the right order

1. **Upload your long-cached files**

    Upload these before the pages that refer to them, so that a page never refers to a file that isn't there yet.

1. **Upload `*.html` and your other pages**

    You can start as soon as the long-cached files have finished uploading. There's no need to wait for any propagation.

1. **Upload your service worker's script**

    If your site has a service worker, upload its script after everything else. See [Service worker scripts](#service-worker-scripts).

## Service worker scripts

A service worker's script, such as `/sw.js`, is the one `*.js` file that you *can't* fingerprint.

Your pages tell browsers where the service worker is, but if your old worker serves visitors cached copies of your pages, those pages keep pointing at the old name — so visitors may never get the new one.

So, whenever you change your service worker's script:

1. **Upload it at the same URL as before, after the rest of your website**

    Your service worker can only use files that are already there.

1. **Purge the script from the pull zone**

    Once everything has finished uploading, purge the service worker's script from the pull zone in the bunny.net dashboard.

!!! danger "Don't set `updateViaCache` to `"all"`"

    When you register your service worker with `navigator.serviceWorker.register()`, either omit `updateViaCache` or set it to `"none"`.

    With `"all"`, browsers can keep using their own cached copy for up to a day, and purging the CDN won't reach it.

### Imported scripts

Scripts that your service worker imports with `importScripts()` or `import` aren't special. Browsers cache them for a year like any other `*.js` file, so fingerprint them.

When one of these scripts changes, update your service worker's script to import the new name, then upload and purge the service worker's script as above.
