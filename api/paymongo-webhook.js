import crypto from "crypto";
export const config={api:{bodyParser:false}};
async function raw(req){const chunks=[];for await(const c of req)chunks.push(c);return Buffer.concat(chunks)}
export default async function handler(req,res){
 if(req.method!=="POST")return res.status(405).end();
 try{
  const body=await raw(req),sig=req.headers["paymongo-signature"]||"";
  // Verify using the exact signature format specified by your current PayMongo webhook documentation.
  // PayMongo's signature scheme can change; configure and test this before production.
  if(!process.env.PAYMONGO_WEBHOOK_SECRET)return res.status(500).json({error:"Missing webhook secret"});
  const event=JSON.parse(body.toString("utf8"));
  // Idempotency and order fulfillment should be implemented server-side with Supabase service-role access.
  // Never trust client-side redirects as payment confirmation.
  return res.status(200).json({received:true,type:event.data?.attributes?.type||event.data?.type||"unknown"});
 }catch(e){return res.status(400).json({error:e.message})}
}