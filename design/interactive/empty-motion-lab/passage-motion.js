// One periodic pose for the hinge, the interior and the light on the floor.
// The door remains inviting even at the quietest point of the seven-second loop.
export const PASSAGE_PERIOD = 7;
export function passagePose(seconds, mode = 0, engagement = 0) {
  const phase = 2 * Math.PI * seconds / PASSAGE_PERIOD;
  const breath = (1 - Math.cos(phase)) / 2;
  const amplitude = mode === 2 ? .13 : mode === 1 ? .17 : .22;
  const invitation = Math.max(0, Math.min(1, engagement));
  return {
    angle: .72 + amplitude * breath + .25 * invitation,
    light: .40 + .15 * breath + .12 * invitation,
    spillOpacity: .13 + .055 * breath + .035 * invitation,
    spillLength: .86 + .12 * breath + .10 * invitation,
  };
}
