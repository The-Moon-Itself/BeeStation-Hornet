import { useBackend } from '../backend';
import { PaintCanvas } from './Canvas';
import { Box } from '../components';
import { Window } from '../layouts';

const PX_PER_UNIT = 12;

const getImageSize = (value) => {
  const width = value.length;
  const height = width !== 0 ? value[0].length : 0;
  return [width, height];
};

export const Bitmap = (props, context) => {
  const { act, data } = useBackend(context);
  const dotsize = PX_PER_UNIT;
  const [width, height] = getImageSize(data.grid);
  return (
    <Window width={Math.min(700, width * dotsize + 72)} height={Math.min(700, height * dotsize + 72)}>
      <Window.Content>
        <Box textAlign="center">
          <PaintCanvas value={data.grid} dotsize={dotsize} onCanvasClick={(x, y) => act('clicked', { x, y })} />
        </Box>
      </Window.Content>
    </Window>
  );
};
