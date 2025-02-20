{ channels, ... }: final: prev: {
  bun = channels.unstable.bun.overrideAttrs (old: {
    meta = old.meta // {
      mainProgram = "bun";
    };
  });
}
