export default async function handler(req,res){
 if(req.method!=="POST")return res.status(405).json({error:"Method not allowed"});
 try{
  const {items=[]}=req.body||{};
  if(!items.length)return res.status(400).json({error:"Cart is empty"});
  const line_items=items.map(i=>({currency:"PHP",amount:Math.round(Number(i.price)*100),description:String(i.title).slice(0,120),quantity:Number(i.qty)}));
  const r=await fetch("https://api.paymongo.com/v1/checkout_sessions",{method:"POST",headers:{"Authorization":"Basic "+Buffer.from(process.env.PAYMONGO_SECRET_KEY+":").toString("base64"),"Content-Type":"application/json"},body:JSON.stringify({data:{attributes:{send_email_receipt:false,show_description:true,show_line_items:true,line_items,payment_method_types:["gcash","card"],success_url:(process.env.APP_URL||"")+"?payment=success",cancel_url:(process.env.APP_URL||"")+"?payment=cancel"}}})});
  const j=await r.json(); if(!r.ok)throw new Error(j.errors?.[0]?.detail||"PayMongo error");
  return res.status(200).json({checkout_url:j.data.attributes.checkout_url});
 }catch(e){return res.status(500).json({error:e.message})}
}