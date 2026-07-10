/**
 * workers/gemini-proxy/src/index.ts
 * Cloudflare Workers proxy for Gemini API.
 * Forwards image analysis requests without exposing the API key to the client.
 * Related: lib/src/services/gemini_api_service.dart
 */

const MODEL = 'gemini-2.5-flash';
const BASE_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

interface AnalysisRequest {
  imageBase64: string;
  mimeType: string;
  today?: string;
  timezone?: string;
}

interface Draft {
  title: string;
  category: string;
  dueDate: string | null;
  amount: number | null;
  items: string[];
  note: string | null;
}

interface AnalysisResponse {
  drafts: Draft[];
}

export default {
  async fetch(request: Request, env: { GEMINI_API_KEY: string }): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const apiKey = env.GEMINI_API_KEY;
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'API key not configured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    let body: AnalysisRequest;
    try {
      body = await request.json();
      if (!body.imageBase64 || !body.mimeType) {
        return new Response(
          JSON.stringify({ error: 'Missing imageBase64 or mimeType' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } },
        );
      }
    } catch {
      return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // today と timezone はクライアントから渡されなければ現在日時/既定値を使う

    const today = body.today ?? new Date().toISOString().slice(0, 10);
    const timezone = body.timezone ?? 'Asia/Tokyo';

    const prompt = `あなたは学校・園からのお知らせを解析するアシスタントです。
与えられた画像から以下の情報を抽出し、JSONの配列で返してください。

今日の日付は ${today}、タイムゾーンは ${timezone} です。

各ToDoは以下を含みます：
- title: タイトル（例：「体操着を持参」「集金袋を提出」）
- category: "payment"（金額あり）| "submit"（提出物）| "event"（行事）| "item"（持ち物）| "other"
- dueDate: 期限日（YYYY-MM-DD形式、画像内の日付から特定できる場合のみ。不明ならnull）
- amount: 金額（整数。円単位。金額がない場合はnull）
- items: 持ち物リスト（辞書的な列挙がある場合。なければ空配列）
- note: 補足事項

重要：
- 「明日」「明後日」「来週」などの相対表現は今日の日付 ${today} を基準に解決すること
- 手書き文字も可能な限り読み取ること
- 複数のToDoがある場合はそれぞれ個別のdraftとして返す`;

    const geminiPayload = {
      contents: [
        {
          parts: [
            { text: prompt },
            {
              inline_data: {
                mime_type: body.mimeType,
                data: body.imageBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: 'application/json',
        response_schema: {
          type: 'object',
          properties: {
            drafts: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  title: { type: 'string' },
                  category: { type: 'string' },
                  dueDate: { type: 'string', nullable: true },
                  amount: { type: 'integer', nullable: true },
                  items: { type: 'array', items: { type: 'string' } },
                  note: { type: 'string', nullable: true },
                },
                required: ['title', 'category', 'items'],
              },
            },
          },
          required: ['drafts'],
        },
      ],
    };

    try {
      const response = await fetch(`${BASE_URL}?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(geminiPayload),
      });

      const data = await response.json();
      return new Response(JSON.stringify(data), {
        status: response.status,
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'Failed to call Gemini API', detail: String(e) }),
        { status: 502, headers: { 'Content-Type': 'application/json' } },
      );
    }
  },
};
