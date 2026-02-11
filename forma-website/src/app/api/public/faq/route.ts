import { NextResponse } from "next/server";
import { createApiEnvelope, publicFaqItems } from "@/lib/public-data";

export function GET() {
  return NextResponse.json(
    createApiEnvelope({
      items: publicFaqItems,
    }),
    {
      headers: {
        "Cache-Control": "public, max-age=3600, s-maxage=3600",
      },
    }
  );
}

