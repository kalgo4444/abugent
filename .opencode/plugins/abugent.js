/**
 * abugent plugin for OpenCode.
 *
 * Registers the skills in ../../skills so OpenCode finds them without
 * symlinks or manual config. Works on both OpenCode flavors:
 *
 * V1 (1.x): named export AbugentPlugin; the `config` hook appends the skills
 * directory to config.skills.paths.
 *
 * V2 (2.x): default export { id, setup }; setup() reads every
 * skills/<name>/SKILL.md and registers it through ctx.skill.transform().
 *
 * No dependencies. Modeled on obra/superpowers' OpenCode plugin (MIT).
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const skillsDir = path.resolve(__dirname, '../../skills');

// Minimal frontmatter parser: `key: value` lines, quoted values, block
// scalars (`>`, `|`) and CRLF. Not full YAML; enough for name, description and
// disable-model-invocation.
const parseFrontmatter = (text) => {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content: text };

  const frontmatter = {};
  let lastKey = null;
  for (const rawLine of match[1].split('\n')) {
    const line = rawLine.replace(/\r$/, '');
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0 && !/^\s/.test(line)) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim();
      frontmatter[key] = /^(>[+-]?|\|[+-]?)$/.test(value) ? '' : value;
      lastKey = key;
    } else if (lastKey !== null && line.trim() !== '') {
      frontmatter[lastKey] = `${frontmatter[lastKey]} ${line.trim()}`.trim();
    }
  }
  for (const key of Object.keys(frontmatter)) {
    frontmatter[key] = frontmatter[key].replace(/^(["'])([\s\S]*)\1$/, '$2');
  }
  return { frontmatter, content: match[2] };
};

// V1: OpenCode discovers skills from config.skills.paths.
export const AbugentPlugin = async () => ({
  config: async (config) => {
    // V2: skills is a flat array; setup() registers skills there instead.
    if (Array.isArray(config.skills)) return;

    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    if (!config.skills.paths.includes(skillsDir)) {
      config.skills.paths.push(skillsDir);
    }
  },
});

// V2: register each skill natively.
async function setup(ctx) {
  // V1 also calls default.setup, but with a ctx that has no skill domain.
  if (!ctx || !ctx.skill || typeof ctx.skill.transform !== 'function') return;

  try {
    const skills = [];
    if (fs.existsSync(skillsDir)) {
      for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true })) {
        if (!entry.isDirectory() || entry.name.startsWith('.')) continue;
        const skillPath = path.join(skillsDir, entry.name, 'SKILL.md');
        if (!fs.existsSync(skillPath)) continue;

        const { frontmatter, content } = parseFrontmatter(fs.readFileSync(skillPath, 'utf8'));
        skills.push({
          id: entry.name,
          name: frontmatter.name || entry.name,
          ...(frontmatter.description ? { description: frontmatter.description } : {}),
          // Manual-only skills (grill-me, handoff, teach) stay out of the
          // model's skill list but can still be loaded by id.
          ...(frontmatter['disable-model-invocation'] === 'true' ? { autoinvoke: false } : {}),
          path: skillPath,
          content,
        });
      }
    }
    await ctx.skill.transform((draft) => {
      // A throw escaping this callback disables the whole plugin, so contain
      // failures per skill.
      for (const skill of skills) {
        try {
          draft.add(skill);
        } catch (err) {
          console.error(`[abugent] skill "${skill.id}" rejected by host, skipping:`, err);
        }
      }
    });
  } catch (err) {
    // Never break plugin activation.
    console.error('[abugent] skill registration failed:', err);
  }
}

export default {
  id: 'abugent',
  server: AbugentPlugin,
  setup,
};
