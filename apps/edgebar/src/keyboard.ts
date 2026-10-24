import { call } from "./ipc";

export function takeKeyboard(): void {
  call("take_keyboard").catch(() => {});
}

export function releaseKeyboard(): void {
  if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
  call("release_keyboard").catch(() => {});
}

export function keyboardField(area: HTMLElement): void {
  area.style.setProperty("-webkit-user-select", "text");
  area.style.setProperty("user-select", "text");
  area.addEventListener("pointerdown", takeKeyboard);
}
