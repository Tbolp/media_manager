import Lightbox from 'yet-another-react-lightbox';
import Zoom from 'yet-another-react-lightbox/plugins/zoom';
import 'yet-another-react-lightbox/styles.css';
import { useAuthStore } from '@/stores/auth';
import { getRawImageUrl } from '@/api/playback';
import type { FileItem } from '@/api/types';

interface Props {
  images: FileItem[];
  index: number;
  open: boolean;
  onClose: () => void;
}

export default function ImageLightbox({ images, index, open, onClose }: Props) {
  const token = useAuthStore((s) => s.token);

  const slides = images.map((img) => ({
    src: getRawImageUrl(img.id, token ?? ''),
  }));

  return (
    <Lightbox
      open={open}
      close={onClose}
      index={index}
      slides={slides}
      plugins={[Zoom]}
    />
  );
}
