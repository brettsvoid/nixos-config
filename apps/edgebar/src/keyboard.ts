import { call } from "./ipc";

export function takeKeyboard(): void {
  call("take_keyboard").catch(() => {});
}

export function releaseKeyboard(): void {
  if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
  call("release_keyboard").catch(() => {});
}

export function keyboardField(area: HTMLElement): void {
  area.addEventListener("pointerdown", takeKeyboard);
}
