import { ImageResponse } from "next/og";

export const runtime = "nodejs";

export const alt = "Forma - Intelligent file organizer for macOS";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: "linear-gradient(135deg, #FFFFFF 0%, #F2F4F7 100%)",
          fontFamily: "system-ui, sans-serif",
        }}
      >
        {/* Grid logo */}
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            width: "54px",
            gap: "6px",
            marginBottom: "32px",
          }}
        >
          {[1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4].map((opacity, i) => (
            <div
              key={i}
              style={{
                width: "14px",
                height: "14px",
                borderRadius: "50%",
                backgroundColor: "#1A1A1A",
                opacity,
              }}
            />
          ))}
        </div>

        {/* Title */}
        <div
          style={{
            fontSize: "64px",
            fontWeight: 400,
            color: "#1A1A1A",
            textAlign: "center",
            lineHeight: 1.1,
            maxWidth: "900px",
            letterSpacing: "-0.02em",
          }}
        >
          A file organizer for people who gave up on file organizers.
        </div>

        {/* Subtitle */}
        <div
          style={{
            fontSize: "24px",
            color: "rgba(26, 26, 26, 0.65)",
            marginTop: "24px",
            textAlign: "center",
          }}
        >
          $29. Once. Forever. macOS native.
        </div>

        {/* Brand name */}
        <div
          style={{
            position: "absolute",
            bottom: "40px",
            fontSize: "20px",
            fontWeight: 600,
            color: "rgba(26, 26, 26, 0.5)",
            letterSpacing: "0.05em",
          }}
        >
          formafiles.com
        </div>
      </div>
    ),
    { ...size }
  );
}
