# THREADLINE Fashion Marketplace

## Quick start
1. Copy `.env.example` to `.env.local`.
2. Fill in Supabase public URL/key and PayMongo secret key.
3. Run `npm install`.
4. Run `npm run dev`.

## Important production notes
This starter contains the frontend and checkout-session endpoint. A production marketplace must create pending orders server-side before checkout and mark them paid only after a verified PayMongo webhook. Do not put Supabase service-role or PayMongo secret keys in browser code.
