import {NextResponse} from 'next/server';
import {createClient} from '@supabase/supabase-js';
import {serverDb} from '@/lib/server-db';
export const runtime='nodejs';
export async function POST(req:Request){
 try{
  const token=req.headers.get('authorization')?.match(/^Bearer (.+)$/)?.[1];if(!token)return NextResponse.json({error:'تسجيل الدخول مطلوب'},{status:401});
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL!,anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  const publicDb=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error}=await publicDb.auth.getUser(token);if(error||!user)return NextResponse.json({error:'جلسة غير صالحة'},{status:401});
  const admin=serverDb();const {data:owner}=await admin.from('admin_users').select('role').eq('user_id',user.id).maybeSingle();if(owner?.role!=='owner')return NextResponse.json({error:'للمالك فقط'},{status:403});
  const body=await req.json();const email=String(body.email||'').trim().toLowerCase(),role=body.role==='admin'?'admin':'staff';
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>254)return NextResponse.json({error:'البريد غير صالح'},{status:400});
  // Only existing verified Auth accounts can be promoted. No passwords are handled here.
  const {data:users,error:listError}=await admin.auth.admin.listUsers({perPage:1000});if(listError)throw listError;
  const target=users.users.find(u=>u.email?.toLowerCase()===email&&u.email_confirmed_at);
  if(!target)return NextResponse.json({error:'المستخدم غير موجود أو بريده غير مؤكد. عليه إنشاء حساب أولاً.'},{status:404});
  const {data:existing}=await admin.from('admin_users').select('role').eq('user_id',target.id).maybeSingle();
  if(existing?.role==='owner')return NextResponse.json({error:'لا يمكن تعديل حساب المالك'},{status:403});
  const {error:saveError}=await admin.from('admin_users').upsert({user_id:target.id,role},{onConflict:'user_id'});if(saveError)throw saveError;
  return NextResponse.json({ok:true,user_id:target.id,role});
 }catch{return NextResponse.json({error:'تعذر حفظ المشرف. تأكد من إعداد مفتاح السيرفر وصلاحيات Supabase.'},{status:500})}
}
