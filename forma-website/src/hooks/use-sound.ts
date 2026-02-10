"use client";

import { useState, useCallback } from "react";
import { soundEngine, type SoundType } from "@/lib/sound/sound-engine";

export function useSound() {
  const [enabled, setEnabled] = useState(() => soundEngine.isEnabled);

  const toggle = useCallback(() => {
    const newState = soundEngine.toggle();
    setEnabled(newState);
    return newState;
  }, []);

  const play = useCallback((sound: SoundType) => {
    soundEngine.play(sound);
  }, []);

  return { enabled, toggle, play };
}
