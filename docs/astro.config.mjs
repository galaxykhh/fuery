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
					label: 'Guides',
					items: [
						'guides/queries',
						'guides/widgets',
						'guides/mutations',
						'guides/infinite-queries',
						'guides/query-client',
						'guides/organizing-queries',
						'guides/bloc',
						'guides/lifecycle',
						'guides/testing',
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'fuery API', link: 'https://pub.dev/documentation/fuery/latest/' },
						{ label: 'fuery_core API', link: 'https://pub.dev/documentation/fuery_core/latest/' },
						{ label: 'Example app', link: 'https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example' },
					],
				},
			],
		}),
	],
});
