import { NextResponse } from "next/server";
import { createApiEnvelope, publicFaqItems } from "@/lib/public-data";

type RouteParams = {
  params: Promise<{
    id: string;
  }>;
};

export async function GET(_: Request, { params }: RouteParams) {
  const { id } = await params;
  const item = publicFaqItems.find((faqItem) => faqItem.id === id);

  if (!item) {
    return NextResponse.json(
      createApiEnvelope({
        error: "FAQ item not found",
      }),
      { status: 404 }
    );
  }

  return NextResponse.json(createApiEnvelope(item), {
    headers: {
      "Cache-Control": "public, max-age=3600, s-maxage=3600",
    },
  });
}

