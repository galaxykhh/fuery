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
			sidebar: [
				{ label: 'Getting started', slug: 'getting-started' },
				{
					label: 'Concepts',
					items: ['server-state', 'how-the-cache-works'],
				},
				{
					label: 'Guides',
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
					items: [
						'reference/query-options',
						'reference/query-results',
						'reference/mutation-options',
						'reference/mutation-results',
						'reference/query-client',
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
