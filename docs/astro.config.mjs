// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { readFileSync } from 'node:fs';

// English at the root, and a folder of src/content/docs for each other
// language. tool/check_translations.py reads the same file.
const locales = JSON.parse(readFileSync(new URL('./i18n/locales.json', import.meta.url), 'utf8'));

export default defineConfig({
	site: 'https://galaxykhh.github.io',
	base: '/fuery',
	integrations: [
		starlight({
			title: 'Fuery',
			description: 'Fetch, cache, and keep server data fresh in Flutter.',
			defaultLocale: 'root',
			locales,
			// Page titles and structured data: see src/routeData.ts.
			routeMiddleware: './src/routeData.ts',
			head: [
				{ tag: 'meta', attrs: { property: 'og:image', content: 'https://galaxykhh.github.io/fuery/og.png' } },
				{ tag: 'meta', attrs: { property: 'og:image:width', content: '1280' } },
				{ tag: 'meta', attrs: { property: 'og:image:height', content: '640' } },
				{ tag: 'meta', attrs: { property: 'og:image:alt', content: 'Fuery: server state for Flutter' } },
			],
			logo: {
				light: './src/assets/mark.svg',
				dark: './src/assets/mark-dark.svg',
			},
			customCss: ['@fontsource-variable/inter', './src/styles/theme.css'],
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/galaxykhh/fuery' }],
			editLink: {
				baseUrl: 'https://github.com/galaxykhh/fuery/edit/main/docs/',
			},
			// A page's sidebar label is its title, which each translation
			// translates. A label written here needs `translations` instead,
			// keyed by each language's `lang` in i18n/locales.json.
			sidebar: [
				'getting-started',
				'coming-from-tanstack-query',
				{
					label: 'Concepts',
					translations: { ko: '개념', ja: '概念', 'zh-CN': '概念' },
					items: ['server-state', 'how-the-cache-works'],
				},
				{
					label: 'Guides',
					translations: { ko: '가이드', ja: 'ガイド', 'zh-CN': '指南' },
					items: [
						'guides/queries',
						'guides/widgets',
						'guides/mutations',
						'guides/infinite-queries',
						'guides/streaming',
						'guides/organizing-queries',
						'guides/query-client',
						'guides/client-setup',
						'guides/lifecycle',
						'guides/persistence',
						'guides/hooks',
						'guides/bloc',
						'guides/testing',
						'guides/devtools',
						'guides/adapters',
					],
				},
				{
					label: 'Reference',
					translations: { ko: '레퍼런스', ja: 'リファレンス', 'zh-CN': '参考' },
					items: [
						'reference/query-options',
						'reference/query-results',
						'reference/mutation-options',
						'reference/mutation-results',
						'reference/query-client',
						{ label: 'fuery API', link: 'https://pub.dev/documentation/fuery/latest/' },
						{ label: 'fuery_core API', link: 'https://pub.dev/documentation/fuery_core/latest/' },
						{ label: 'fuery_hooks API', link: 'https://pub.dev/documentation/fuery_hooks/latest/' },
						{
							label: 'Example app',
							translations: { ko: '예제 앱', ja: 'サンプルアプリ', 'zh-CN': '示例应用' },
							link: 'https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example',
						},
					],
				},
				'troubleshooting',
			],
		}),
	],
});
