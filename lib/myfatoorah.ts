import 'server-only';
const base = process.env.MYFATOORAH_ENV === 'live' ? 'https://api.myfatoorah.com' : 'https://apitest.myfatoorah.com';
export function paymentEnabled() { return Boolean(process.env.MYFATOORAH_API_KEY && process.env.MYFATOORAH_ENV === 'live' && process.env.MYFATOORAH_LIVE_ENABLED === 'true'); }
export async function mf(path:string, payload:object) {
 const token=process.env.MYFATOORAH_API_KEY;
 if(!token) throw new Error('لم يتم تفعيل حساب MyFatoorah بعد');
 const r=await fetch(`${base}/v2/${path}`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json',Accept:'application/json'},body:JSON.stringify(payload),cache:'no-store'});
 const j=await r.json();if(!r.ok||!j.IsSuccess)throw new Error('MyFatoorah: '+(j.Message||r.status));return j.Data;
}
