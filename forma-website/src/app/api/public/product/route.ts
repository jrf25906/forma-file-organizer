import { NextResponse } from "next/server";
import { createApiEnvelope, publicProduct } from "@/lib/public-data";

export function GET() {
  return NextResponse.json(createApiEnvelope(publicProduct), {
    headers: {
      "Cache-Control": "public, max-age=3600, s-maxage=3600",
    },
  });
}

