import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const url=Deno.env.get("SUPABASE_URL")??"";
let secret=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
try{
  const values=Object.values(JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS")??"{}"));
  const key=values.find(v=>typeof v==="string"&&v.startsWith("sb_secret_"));
  if(typeof key==="string")secret=key;
}catch{/* legacy key fallback */}
const origins=new Set(["https://cv-ats-web.vercel.app",
  "https://cv-ats-web-ahmed-braieks-projects.vercel.app"]);
function headers(req:Request){
 const origin=req.headers.get("origin")??"";
 return {"Content-Type":"application/json",
  "Access-Control-Allow-Origin":origins.has(origin)?origin:"null",
  "Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info",
  "Access-Control-Allow-Methods":"POST,OPTIONS","Vary":"Origin"};
}
function reply(req:Request,status:number,body:unknown){
 return new Response(JSON.stringify(body),{status,headers:headers(req)});
}
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:headers(req)});
 if(req.method!=="POST")return reply(req,405,{error:"method_not_allowed"});
 if(!url||!secret)return reply(req,503,{error:"backend_unconfigured"});
 const bearer=req.headers.get("authorization")??"";
 if(!/^Bearer \S+$/i.test(bearer))return reply(req,401,{error:"auth_required"});
 const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
 const identity=await admin.auth.getUser(bearer.replace(/^Bearer\s+/i,""));
 if(identity.error||!identity.data.user)return reply(req,401,{error:"invalid_session"});
 const actor=identity.data.user.id;
 let id:unknown;
 try{const payload=await req.json();id=payload?.cvId}catch{return reply(req,400,{error:"invalid_json"})}
 if(typeof id!=="string"||!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id))
   return reply(req,400,{error:"invalid_cv_id"});
 const cv=await admin.from("cvs").select("storage_path,deleted_at")
   .eq("id",id).eq("user_id",actor).maybeSingle();
 if(cv.error)return reply(req,503,{error:"database_unavailable"});
 if(!cv.data||cv.data.deleted_at)return reply(req,404,{error:"cv_not_found"});
 const path=cv.data.storage_path as string;
 if(!path.startsWith(actor+"/"))return reply(req,409,{error:"invalid_storage_path"});
 // The file must be deleted by the Storage API, never directly with SQL.
 const removed=await admin.storage.from("cv-private").remove([path]);
 if(removed.error)return reply(req,503,{error:"storage_cleanup_failed"});
 const cleaned=await admin.rpc("cv_ats_delete_owned_cv",{
   p_actor:actor,p_cv_id:id,
 });
 if(cleaned.error){
   console.error("CV deletion metadata cleanup failed",{code:cleaned.error.code});
   return reply(req,503,{error:"metadata_cleanup_failed_retry"});
 }
 return reply(req,200,{data:cleaned.data});
});
