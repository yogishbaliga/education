export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Deny any attempt to address the assets root by its folder name.
    if (url.pathname.startsWith('/public/')) {
      return new Response('Not Found', { status: 404 });
    }

    return env.ASSETS.fetch(request);
  },
};
