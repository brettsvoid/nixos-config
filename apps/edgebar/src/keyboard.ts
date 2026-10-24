import { call } from "./ipc";

// The bar window never takes the keyboard on its own (keyboard.rs), so a key
// press goes to the app in front. A text field in a notch view calls
// `keyboardField` on itself: pressing it takes the keyboard, and main.ts gives
// it back when the notch closes, to the app that was in front.

export function takeKeyboard(): void {
  call("take_keyboard").catch(() => {});
}

// Safe to call when the keyboard isn't held.
export function releaseKeyboard(): void {
  if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
  call("release_keyboard").catch(() => {});
}

// Pressing the field takes the keyboard. Text fields also need `user-select:
// text`, which the body turns off.
export function keyboardField(field: HTMLInputElement | HTMLTextAreaElement): void {
  field.addEventListener("pointerdown", takeKeyboard);
}
