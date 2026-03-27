# TGF Parkrun Dashboard

The frontend component of the Parkrun Data Dive. This is an **Astro SSR** application optimized for mobile devices and secure data handling.

## 🛠 Technical Implementation

- **SSR Mode:** The application runs in server mode (Node/Firebase) to keep BigQuery credentials and raw data off the client side.
- **Shared SQL:** SQL queries are imported directly from the root `/sql` directory using `node:fs`, ensuring the dashboard and ETL never drift apart.
- **Global Styling:** All baseline resets and design tokens (colors/typography) are centralized in `Layout.astro` using `is:global`.

## 📁 Key Directories

- `src/layouts/`: The `Layout.astro` component wraps all pages with a 1024px max-width container and global styles.
- `src/components/`:
  - `HeadlineStats.astro`: A "Smart Widget" that handles its own BigQuery data fetching and key normalization.
  - `Header.astro`: Contains the responsive navigation and animated hamburger-to-X SVG logic.
- `src/lib/`: Backend utilities for BigQuery authentication (ADC compatible).

## 🔐 Security & Privacy

Athlete names are personally identifiable information (PII). This dashboard follows these rules:

1. No JSON data files are ever committed to the repo.
2. Data is fetched on the server; the client only receives rendered HTML.
3. Key normalization ensures that BigQuery's case-sensitive column names are handled gracefully in JavaScript.

```

Astro looks for `.astro` or `.md` files in the `src/pages/` directory. Each page is exposed as a route based on its file name.

There's nothing special about `src/components/`, but that's where we like to put any Astro/React/Vue/Svelte/Preact components.

Any static assets, like images, can be placed in the `public/` directory.

## 🧞 Commands

All commands are run from the root of the project, from a terminal:

| Command                   | Action                                           |
| :------------------------ | :----------------------------------------------- |
| `npm install`             | Installs dependencies                            |
| `npm run dev`             | Starts local dev server at `localhost:4321`      |
| `npm run build`           | Build your production site to `./dist/`          |
| `npm run preview`         | Preview your build locally, before deploying     |
| `npm run astro ...`       | Run CLI commands like `astro add`, `astro check` |
| `npm run astro -- --help` | Get help using the Astro CLI                     |

## 👀 Want to learn more?

Feel free to check [our documentation](https://docs.astro.build) or jump into our [Discord server](https://astro.build/chat).
```
