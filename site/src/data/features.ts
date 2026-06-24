import type { ImageMetadata } from 'astro';
import placeholder from '../assets/placeholder.svg';
import clipboardShot from '../assets/screens/clipboard.png';

export interface Feature {
  id: string;
  eyebrow: string;
  title: string;
  body: string;
  hotkey?: string;
  image: ImageMetadata;
  alt: string;
}

export const features: Feature[] = [
  {
    id: 'clipboard',
    eyebrow: 'Clipboard',
    title: 'Everything you copied, instantly back.',
    body: 'Searchable history with link previews, image clips and QR codes. Hit a number to paste — ⌘1–9.',
    hotkey: '⌃⌥V',
    image: clipboardShot,
    alt: 'Stash clipboard history browser',
  },
  {
    id: 'snippets',
    eyebrow: 'Snippets',
    title: 'Type less, everywhere.',
    body: 'Text-expansion triggers fire system-wide, with dynamic placeholders like {date}, {clipboard} and fill-in fields.',
    hotkey: ':trigger',
    image: placeholder,
    alt: 'Stash snippet editor with placeholders',
  },
  {
    id: 'tasks',
    eyebrow: 'Tasks',
    title: 'Plans in plain English.',
    body: 'Type "pay rent fri 9am !high" and Stash sets the date, time and priority. Recurring tasks and due reminders included.',
    image: placeholder,
    alt: 'Stash tasks with natural-language quick-add',
  },
  {
    id: 'stickies',
    eyebrow: 'Sticky notes',
    title: 'Notes that stay in sight.',
    body: 'Drop sticky notes on your desktop or jot in the notes window — all persisted.',
    hotkey: '⌃⌥S',
    image: placeholder,
    alt: 'Stash sticky notes on the desktop',
  },
  {
    id: 'windows',
    eyebrow: 'Windows',
    title: 'Snap without the mouse.',
    body: 'Keyboard-driven window tiling powered by Accessibility — halves, corners, fullscreen.',
    image: placeholder,
    alt: 'Stash window snapping',
  },
  {
    id: 'focus',
    eyebrow: 'Focus',
    title: 'A timer in your menu bar.',
    body: 'Pomodoro sessions that count down right where you can see them.',
    image: placeholder,
    alt: 'Stash focus timer in the menu bar',
  },
  {
    id: 'ai',
    eyebrow: 'AI & palette',
    title: 'Command everything with ⌘K.',
    body: 'A fuzzy command palette for every action, plus an AI tab to put your day in order.',
    hotkey: '⌘K',
    image: placeholder,
    alt: 'Stash command palette',
  },
];
