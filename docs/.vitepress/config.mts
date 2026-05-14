import { defineConfig } from 'vitepress'
import brunostGrammar from './brunost.tmLanguage.json'

const enSidebar = [
  {
    text: 'Introduction',
    items: [
      { text: 'Getting Started', link: '/en/' },
    ]
  },
  {
    text: 'Language',
    items: [
      { text: 'Variables', link: '/en/variables' },
      { text: 'Data Types', link: '/en/data-types' },
      { text: 'Control Flow', link: '/en/control-flow' },
      { text: 'Functions', link: '/en/functions' },
      { text: 'Error Handling', link: '/en/error-handling' },
      { text: 'Modules', link: '/en/modules' },
      { text: 'Custom Types', link: '/en/custom-types' },
    ]
  },
  {
    text: 'Standard Library',
    items: [
      { text: 'Overview', link: '/en/stdlib/' },
      { text: 'terminal', link: '/en/stdlib/terminal' },
      { text: 'matte', link: '/en/stdlib/matte' },
      { text: 'streng', link: '/en/stdlib/streng' },
      { text: 'liste', link: '/en/stdlib/liste' },
      { text: 'kart', link: '/en/stdlib/kart' },
      { text: 'prosess', link: '/en/stdlib/prosess' },
      { text: 'fil', link: '/en/stdlib/fil' },
      { text: 'nettverk', link: '/en/stdlib/nettverk' },
      { text: 'http', link: '/en/stdlib/http' },
    ]
  }
]

const nnSidebar = [
  {
    text: 'Innleiing',
    items: [
      { text: 'Kom i gang', link: '/nn/' },
    ]
  },
  {
    text: 'Språket',
    items: [
      { text: 'Variablar', link: '/nn/variables' },
      { text: 'Datatypar', link: '/nn/data-types' },
      { text: 'Kontrollflyt', link: '/nn/control-flow' },
      { text: 'Funksjonar', link: '/nn/functions' },
      { text: 'Feilhandtering', link: '/nn/error-handling' },
      { text: 'Modular', link: '/nn/modules' },
      { text: 'Eigendefinerte typar', link: '/nn/custom-types' },
    ]
  },
  {
    text: 'Standardbibliotek',
    items: [
      { text: 'Oversyn', link: '/nn/stdlib/' },
      { text: 'terminal', link: '/nn/stdlib/terminal' },
      { text: 'matte', link: '/nn/stdlib/matte' },
      { text: 'streng', link: '/nn/stdlib/streng' },
      { text: 'liste', link: '/nn/stdlib/liste' },
      { text: 'kart', link: '/nn/stdlib/kart' },
      { text: 'prosess', link: '/nn/stdlib/prosess' },
      { text: 'fil', link: '/nn/stdlib/fil' },
      { text: 'nettverk', link: '/nn/stdlib/nettverk' },
      { text: 'http', link: '/nn/stdlib/http' },
    ]
  }
]

export default defineConfig({
  base: '/brunost/documentation/',
  title: 'Brunost',
  appearance: 'force-dark',

  head: [
    ['meta', { name: 'color-scheme', content: 'dark' }],
  ],

  markdown: {
    languages: [
      brunostGrammar as any,
    ],
    theme: {
      dark: 'github-dark',
      light: 'github-dark',
    },
  },

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      link: '/en/',
      themeConfig: {
        nav: [
          { text: 'Home', link: 'https://atomfinger.github.io/brunost/' },
          { text: 'Docs', link: '/en/' },
        ],
        sidebar: enSidebar,
        langMenuLabel: 'Language',
      }
    },
    nn: {
      label: 'Nynorsk',
      lang: 'nn',
      link: '/nn/',
      themeConfig: {
        nav: [
          { text: 'Framsida', link: 'https://atomfinger.github.io/brunost/' },
          { text: 'Dokumentasjon', link: '/nn/' },
        ],
        sidebar: nnSidebar,
        langMenuLabel: 'Språk',
        darkModeSwitchLabel: 'Utsjånad',
        sidebarMenuLabel: 'Meny',
        returnToTopLabel: 'Tilbake til toppen',
        outlineTitle: 'På denne sida',
        docFooter: {
          prev: 'Forrige side',
          next: 'Neste side',
        },
      }
    },
  },

  themeConfig: {
    socialLinks: [
      { icon: 'github', link: 'https://github.com/atomfinger/brunost' }
    ],
    search: {
      provider: 'local',
    },
    footer: {
      message: 'Released under the MIT Licence.',
      copyright: 'Copyright © <a href="https://lindbakk.com/">John Mikael Lindbakk</a>',
    },
  },
})
