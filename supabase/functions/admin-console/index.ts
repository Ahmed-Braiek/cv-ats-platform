import { createClient } from "npm:@supabase/supabase-js@2.57.0";

/**
 * Administrative control plane. PRIVATE service key stays only in Supabase
 * Edge runtime. Every request checks a fresh Supabase user and their current
 * profiles.role. UI state and editable JWT metadata are never authorization.
 */
const url = Deno.env.get("SUPABASE_URL") ?? "";
let secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
try {
  const values = Object.values(JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}"));
  const modern = values.find(x => typeof x === "string" && x.startsWith("sb_secret_"));
  if (typeof modern === "string") secret = modern;
} catch { /* fallback for legacy service_role project key */ }
const origins = new Set([
  "https://cv-ats-web.vercel.app",
  "https://cv-ats-web-ahmed-braieks-projects.vercel.app",
]);
const uuid = (x: unknown): x is string =>
  typeof x === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x);
const string = (x: unknown, maximum=500) =>
  typeof x === "string" ? x.trim().slice(0, maximum) : "";
function cors(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  return {
    "Access-Control-Allow-Origin": origins.has(origin) ? origin : "null",
    "Access-Control-Allow-Headers": "authorization,apikey,content-type,x-client-info",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
    "Vary": "Origin",
  };
}
const reply = (req: Request, status: number, data: unknown) =>
  new Response(JSON.stringify(data),{status,headers:cors(req)});
const number = (x: unknown, low: number, high: number, fallback: number) =>
  Number.isInteger(x) && (x as number)>=low && (x as number)<=high
    ? x as number : fallback;
const deny = (req: Request,status: number,code: string) =>
  reply(req,status,{error:code});

Deno.serve(async req => {
  if(req.method === "OPTIONS")return new Response(null,{status:204,headers:cors(req)});
  if(req.method !== "POST")return deny(req,405,"method_not_allowed");
  if(!url||!secret)return deny(req,503,"backend_not_configured");
  const bearer=req.headers.get("authorization")??"";
  if(!/^Bearer \S+$/i.test(bearer))return deny(req,401,"sign_in_required");
  const admin=createClient(url,secret,{
    auth:{persistSession:false,autoRefreshToken:false},
  });
  const identity=await admin.auth.getUser(bearer.replace(/^Bearer\s+/i,""));
  if(identity.error||!identity.data.user)return deny(req,401,"invalid_session");
  const actor=identity.data.user.id;
  const profile=await admin.from("profiles").select("role").eq("id",actor).maybeSingle();
  if(profile.error||profile.data?.role!=="admin"){
    return deny(req,403,"administrator_required");
  }
  let request: Record<string,unknown>;
  try {
    const body=await req.json();
    if(!body||typeof body!=="object"||Array.isArray(body))throw Error();
    request=body;
  }catch{return deny(req,400,"invalid_json");}
  const action=string(request.action,45);
  const offset=number(request.offset,0,100000,0);
  const limit=number(request.limit,1,50,20);
  const audit=async(kind: string,target: string|null,reason: string,details: object={})=>{
    const {error}=await admin.from("admin_audit_events").insert({
      actor_id:actor,target_id:target,action:kind,reason,details,
    });
    if(error)throw Error("audit_write_failed");
  };
  const rpc=async(name: string,args: Record<string,unknown>={})=>{
    const {data,error}=await admin.rpc(name,args);
    if(error)throw Error("admin_database_operation_failed");
    return data;
  };
  try{
    if(action==="overview"){
      return reply(req,200,{data:await rpc("cv_ats_admin_overview")});
    }
    if(action==="users"){
      return reply(req,200,{data:await rpc("cv_ats_admin_users",{
        p_search:string(request.search,100),p_offset:offset,p_limit:limit,
      })});
    }
    if(action==="analyses"){
      const status=string(request.status,30);
      if(status&&!["queued","extracting","parsing_job","scoring",
        "recommending","completed","failed","cancelled","expired"].includes(status)){
        return deny(req,400,"invalid_status");
      }
      return reply(req,200,{data:await rpc("cv_ats_admin_analyses",{
        p_status:status,p_offset:offset,p_limit:limit,
      })});
    }
    if(action==="plans"){
      const {data,error}=await admin.from("subscription_plans")
        .select("id,code,name,monthly_analysis_limit,saved_cv_limit,history_days,pdf_export_enabled,active")
        .order("monthly_analysis_limit");
      if(error)throw Error("plans_unavailable");
      return reply(req,200,{data:data??[]});
    }
    if(action==="audit"){
      const {data,error,count}=await admin.from("admin_audit_events")
        .select("id,actor_id,target_id,action,reason,details,created_at",{count:"exact"})
        .order("created_at",{ascending:false}).range(offset,offset+limit-1);
      if(error)throw Error("audit_unavailable");
      return reply(req,200,{data:{items:data??[],total:count??0}});
    }
    if(action==="user"){
      const id=request.userId;
      if(!uuid(id))return deny(req,400,"invalid_user_id");
      const directory=await rpc("cv_ats_admin_users",{
        p_search:id,p_offset:0,p_limit:1,
      });
      const user=(directory as {items?:unknown[]}).items?.[0];
      if(!user)return deny(req,404,"user_not_found");
      const {data:recent,error}=await admin.from("analyses")
        .select("id,status,created_at,completed_at,evaluator_version")
        .eq("user_id",id).order("created_at",{ascending:false}).limit(12);
      if(error)throw Error("user_history_unavailable");
      return reply(req,200,{data:{user,analyses:recent??[]}});
    }
    const reason=string(request.reason,500);
    if(reason.length<8)return deny(req,400,"reason_too_short");
    if(action==="grant_plan"){
      const id=request.userId,plan=string(request.plan,30);
      if(!uuid(id)||!["free","premium"].includes(plan))return deny(req,400,"invalid_plan_change");
      const data=await rpc("cv_ats_admin_grant_plan",{
        p_actor:actor,p_target:id,p_plan_code:plan,p_reason:reason,
      });
      return reply(req,200,{data});
    }
    if(action==="update_plan"){
      const code=string(request.plan,30);
      if(!["free","premium"].includes(code))return deny(req,400,"invalid_plan");
      const monthly=number(request.monthly,1,10000,-1);
      const saved=number(request.saved,1,10000,-1);
      const history=request.history===null?null:number(request.history,1,3650,-1);
      if(monthly<1||saved<1||history===-1||typeof request.pdf!=="boolean")
        return deny(req,400,"invalid_plan_limits");
      const data=await rpc("cv_ats_admin_update_plan",{
        p_actor:actor,p_code:code,p_monthly:monthly,p_saved:saved,
        p_history:history,p_export:request.pdf,p_reason:reason,
      });
      return reply(req,200,{data});
    }
    if(action==="suspend"||action==="restore"){
      const id=request.userId;
      if(!uuid(id)||id===actor)return deny(req,400,"invalid_target");
      const target=await admin.from("profiles").select("role").eq("id",id).maybeSingle();
      if(target.error||target.data?.role!=="candidate")return deny(req,403,"candidate_only");
      const updated=await admin.auth.admin.updateUserById(id,{
        ban_duration:action==="suspend"?"876000h":"0s",
      });
      if(updated.error)throw Error("account_restriction_failed");
      await audit(action==="suspend"?"account.suspended":"account.restored",id,reason);
      return reply(req,200,{data:{status:action==="suspend"?"suspended":"active"}});
    }
    if(action==="cancel_analysis"){
      const id=request.analysisId;
      if(!uuid(id))return deny(req,400,"invalid_analysis_id");
      const {data,error}=await admin.from("analyses")
        .update({status:"cancelled",failure_code:"cancelled_by_admin"})
        .eq("id",id).in("status",["queued","extracting","parsing_job","scoring","recommending"])
        .select("id,status").maybeSingle();
      if(error)throw Error("analysis_cancel_failed");
      if(!data)return deny(req,409,"analysis_not_active");
      await audit("analysis.cancelled",null,reason,{analysis_id:id});
      return reply(req,200,{data});
    }
    if(action==="delete_user"){
      const id=request.userId;
      const email=string(request.confirmEmail,320);
      if(!uuid(id)||id===actor||request.confirm!=="DELETE"||!email)
        return deny(req,400,"confirmation_required");
      const existing=await admin.auth.admin.getUserById(id);
      if(existing.error||!existing.data.user)return deny(req,404,"user_not_found");
      if(existing.data.user.email?.toLowerCase()!==email.toLowerCase())
        return deny(req,400,"email_confirmation_mismatch");
      const target=await admin.from("profiles").select("role").eq("id",id).maybeSingle();
      if(target.error||target.data?.role==="admin")
        return deny(req,403,"admin_deletion_forbidden");
      // Storage must be deleted via Storage API, not raw SQL.
      // File paths are always constrained under the verified target UUID.
      for(let page=0;page<25;page++){
        const listed=await admin.storage.from("cv-private").list(id,{limit:500});
        if(listed.error)throw Error("storage_listing_failed");
        const files=(listed.data??[]).filter(x=>x.name&&!x.name.startsWith("."));
        if(!files.length)break;
        const paths=files.map(x=>id+"/"+x.name);
        const removed=await admin.storage.from("cv-private").remove(paths);
        if(removed.error)throw Error("storage_cleanup_failed");
        if(page===24)throw Error("too_many_storage_objects");
      }
      // Transactionally removes analysis dependents, CV rows and subscriptions.
      await rpc("cv_ats_admin_purge_candidate",{
        p_actor:actor,p_target:id,p_reason:reason,
      });
      const deleted=await admin.auth.admin.deleteUser(id);
      if(deleted.error){
        // Recovery: a retry can complete Auth deletion even if app profile
        // was already purged. This failure is audited and returned explicitly.
        await audit("account.auth_delete_failed",id,reason);
        throw Error("auth_deletion_incomplete_retry");
      }
      await audit("account.deleted",id,reason,{storage_cleaned:true});
      return reply(req,200,{data:{status:"deleted"}});
    }
    return deny(req,400,"unknown_action");
  }catch(error){
    const code=error instanceof Error?error.message:"admin_operation_failed";
    console.error("Admin operation failure",{
      action,code:code.slice(0,90),actor, /* no CVs, secrets or email addresses in logs */
    });
    return deny(req,code==="auth_deletion_incomplete_retry"?503:500,
      /^([a-z_]+)$/.test(code)?code:"admin_operation_failed");
  }
});
