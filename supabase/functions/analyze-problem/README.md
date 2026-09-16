# analyze-problem Edge Function

This function powers Harafi Smart Assistant.

## What it does

- Accepts a problem description, follow-up answers, and an optional image payload.
- Returns a structured diagnosis object for the Flutter app.
- Falls back to a local keyword-based diagnosis if no AI provider is configured.

## Environment variables

Set these in your Supabase project before deploying:

- `OPENAI_API_KEY`
- `OPENAI_MODEL` (optional, defaults to `gpt-5.6-sol`)

## Request body

```json
{
  "description": "washing machine makes loud noise and does not spin",
  "answers": [
    { "question": "Does it drain water?", "answer": "Yes" }
  ],
  "image_base64": "optional base64 image data",
  "image_name": "optional.jpg"
}
```

## Response body

```json
{
  "detectedCategory": "washing_machine",
  "categoryNameAr": "غسالات",
  "confidence": 0.82,
  "problemSummary": "The washing machine makes a loud noise.",
  "possibleIssue": "The issue may be related to the spin system.",
  "needsTechnician": true,
  "urgency": "normal",
  "followUpQuestions": [
    "Does it drain water properly?",
    "Does the noise happen only during spin?"
  ]
}
```

## Deploy

```bash
supabase functions deploy analyze-problem
```

If you want the function to use a real AI provider, make sure the env vars are set first.

Suggested production setup:

- Start with `OPENAI_MODEL=gpt-5.6-sol` for the strongest analysis quality.
- If you want lower cost later, switch the model by env var only; the app code does not need to change.
