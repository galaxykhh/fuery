import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

const home = 'https://galaxykhh.github.io/fuery/';

// Runs for every page after Starlight builds its <head>.
export const onRequest = defineRouteMiddleware((context) => {
	const route = context.locals.starlightRoute;
	const { id, entry } = route;

	// The 404 page is served for any missing path, so it has no canonical URL
	// and stays out of search results.
	if (id === '404') {
		route.head = route.head.filter((tag) => !(tag.tag === 'link' && tag.attrs?.rel === 'canonical'));
		route.head.push({ tag: 'meta', attrs: { name: 'robots', content: 'noindex' } });
		return;
	}

	// "Queries | Fuery" becomes "Queries | Fuery for Flutter". A page keeps its
	// title when it sets its own <title> in the frontmatter `head`, or when its
	// title already says Flutter.
	const title = route.head.find((tag) => tag.tag === 'title');
	if (title?.content === `${entry.data.title} | Fuery` && !/flutter/i.test(entry.data.title)) {
		title.content = `${entry.data.title} | Fuery for Flutter`;
	}

	// Structured data: the project on the home page, a breadcrumb on the others.
	const url = new URL(context.url.pathname, context.site).href;
	const data =
		id === ''
			? {
					'@context': 'https://schema.org',
					'@type': 'SoftwareSourceCode',
					name: 'Fuery',
					description: entry.data.description,
					url: home,
					codeRepository: 'https://github.com/galaxykhh/fuery',
					programmingLanguage: 'Dart',
					runtimePlatform: 'Flutter',
					license: 'https://github.com/galaxykhh/fuery/blob/main/LICENSE',
					sameAs: [
						'https://pub.dev/packages/fuery',
						'https://pub.dev/packages/fuery_core',
						'https://pub.dev/packages/fuery_hooks',
					],
				}
			: {
					'@context': 'https://schema.org',
					'@type': 'BreadcrumbList',
					itemListElement: [
						{ '@type': 'ListItem', position: 1, name: 'Fuery', item: home },
						{ '@type': 'ListItem', position: 2, name: entry.data.title, item: url },
					],
				};
	route.head.push({ tag: 'script', attrs: { type: 'application/ld+json' }, content: JSON.stringify(data) });
});
