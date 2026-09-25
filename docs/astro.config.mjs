// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
	site: 'https://galaxykhh.github.io',
	base: '/fuery',
	integrations: [
		starlight({
			title: 'Fuery',
			description: 'Fetch, cache, and keep server data fresh in Flutter.',
			head: [
				{
					tag: 'script',
					attrs: { type: 'application/ld+json' },
					content: JSON.stringify({
						'@context': 'https://schema.org',
						'@type': 'SoftwareSourceCode',
						name: 'Fuery',
						description:
							'Server data caching for Flutter and Dart: queries, mutations, pagination, and offline support.',
						codeRepository: 'https://github.com/galaxykhh/fuery',
						programmingLanguage: 'Dart',
						license: 'https://github.com/galaxykhh/fuery/blob/main/LICENSE',
						url: 'https://galaxykhh.github.io/fuery/',
					}),
				},
				{ tag: 'meta', attrs: { property: 'og:image', content: 'https://galaxykhh.github.io/fuery/og.png' } },
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
			sidebar: [
				{ label: 'Getting started', slug: 'getting-started' },
				{
					label: 'Concepts',
					items: ['server-state', 'guides/organizing-queries'],
				},
				{
					label: 'Guides',
					items: [
						'guides/queries',
						'guides/widgets',
						'guides/hooks',
						'guides/mutations',
						'guides/infinite-queries',
						'guides/streaming',
						'guides/persistence',
						'guides/query-client',
						'guides/client-setup',
						'guides/lifecycle',
						'guides/bloc',
						'guides/testing',
						'guides/devtools',
					],
				},
				{
					label: 'Reference',
					items: [
						'reference/query-client',
						'reference/query-options',
						{ label: 'fuery API', link: 'https://pub.dev/documentation/fuery/latest/' },
						{ label: 'fuery_core API', link: 'https://pub.dev/documentation/fuery_core/latest/' },
						{ label: 'fuery_hooks API', link: 'https://pub.dev/documentation/fuery_hooks/latest/' },
						{ label: 'Example app', link: 'https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example' },
					],
				},
				{ label: 'Troubleshooting', slug: 'troubleshooting' },
			],
		}),
	],
});
