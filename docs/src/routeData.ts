import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

const site = 'https://galaxykhh.github.io/fuery/';

// What follows a page title, by the `lang` of each language in
// i18n/locales.json. A language missing here gets the English one.
const titleSuffix: Record<string, string> = {
	en: 'Fuery for Flutter',
	ko: 'Flutter용 Fuery',
	ja: 'Flutter 向け Fuery',
	'zh-CN': '适用于 Flutter 的 Fuery',
};

// Runs for every page after Starlight builds its <head>, which already links
// the page in every language with hreflang alternates.
export const onRequest = defineRouteMiddleware((context) => {
	const route = context.locals.starlightRoute;
	const { id, entry, lang, locale } = route;

	// The 404 page is served for any missing path, so it has no canonical URL
	// or hreflang alternates, and stays out of search results.
	if (id === '404') {
		route.head = route.head.filter(
			(tag) => !(tag.tag === 'link' && (tag.attrs?.rel === 'canonical' || tag.attrs?.hreflang)),
		);
		route.head.push({ tag: 'meta', attrs: { name: 'robots', content: 'noindex' } });
		return;
	}

	// A page not translated yet shows the English text at the translation's
	// URL. Search engines index the English page instead.
	if (route.isFallback) {
		route.head.push({ tag: 'meta', attrs: { name: 'robots', content: 'noindex' } });
	}

	// "Queries | Fuery" becomes "Queries | Fuery for Flutter", and "쿼리 | Fuery"
	// becomes "쿼리 | Flutter용 Fuery". A page keeps its title when it sets its
	// own <title> in the frontmatter `head`, or when its title already says
	// Flutter.
	const title = route.head.find((tag) => tag.tag === 'title');
	if (title?.content === `${entry.data.title} | Fuery` && !/flutter/i.test(entry.data.title)) {
		title.content = `${entry.data.title} | ${titleSuffix[lang] ?? titleSuffix.en}`;
	}

	// Structured data: the project on the home page, a breadcrumb on the others.
	// Each language has its own home page: /fuery/ for English, /fuery/ko/ for
	// Korean.
	const home = new URL(locale ? `${locale}/` : '', site).href;
	const url = new URL(context.url.pathname, context.site).href;
	const data =
		id === (locale ?? '')
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
