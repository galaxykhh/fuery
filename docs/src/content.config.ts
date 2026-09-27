import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

export const collections = {
	docs: defineCollection({
		loader: docsLoader(),
		schema: docsSchema({
			extend: z.object({
				// A translation's hash of the English page it was translated from.
				// tool/check_translations.py compares it with the English page.
				sourceHash: z.string().optional(),
			}),
		}),
	}),
};
