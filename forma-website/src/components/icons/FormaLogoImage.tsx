import Image from "next/image";
import { cn } from "@/lib/utils";

interface FormaLogoImageProps {
  size: number;
  className?: string;
}

export function FormaLogoImage({ size, className }: FormaLogoImageProps) {
  return (
    <span
      className={cn("relative inline-flex shrink-0", className)}
      style={{ width: size, height: size }}
      aria-hidden="true"
    >
      <Image
        src="/logo.svg"
        alt=""
        width={size}
        height={size}
        className="forma-logo-image-light h-full w-full"
      />
      <Image
        src="/logo-light.svg"
        alt=""
        width={size}
        height={size}
        className="forma-logo-image-dark absolute inset-0 h-full w-full"
      />
    </span>
  );
}

export default FormaLogoImage;
