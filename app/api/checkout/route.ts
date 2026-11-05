import {NextResponse} from 'next/server';
import {serverDb} from '@/lib/server-db';
import {mf,paymentEnabled} from '@/lib/myfatoorah';
export const runtime='nodejs';
const fail=(message:string,status=400)=>NextResponse.json({error:message},{status});
export async function POST(req:Request){
 if(!paymentEnabled())return fail('الدفع الإلكتروني غير مفعّل حالياً. لم يتم تسجيل طلب أو خصم أي مبلغ.',503);
 try{
  const body=await req.json();const items=body.items;
  if(!Array.isArray(items)||!items.length||items.length>50)return fail('السلة غير صالحة');
  const name=String(body.name||'').trim(),mobile=String(body.mobile||'').trim(),address=String(body.address||'').trim();
  if(name.length<2||name.length>120||!/^\d{8}$/.test(mobile)||address.length<10||address.length>500)return fail('يرجى إدخال الاسم ورقم كويتي من 8 أرقام وعنوان التوصيل');
  const qtys=new Map<string,number>();for(const x of items){if(typeof x.id!=='string'||!/^[0-9a-f-]{36}$/i.test(x.id)||!Number.isInteger(x.qty)||x.qty<1||x.qty>99)return fail('كمية غير صالحة');qtys.set(x.id,(qtys.get(x.id)||0)+x.qty)}
  const db=serverDb();const {data:products,error}=await db.from('products').select('id,name_ar,price,stock,published').in('id',[...qtys.keys()]);
  if(error||!products||products.length!==qtys.size)return fail('تعذر التحقق من المنتجات');
  let fils=0;const lines=[];
  for(const x of products){const qty=qtys.get(x.id)!;if(!x.published||x.stock<qty)return fail(`الكمية غير متوفرة: ${x.name_ar}`);const unit=Math.round(Number(x.price)*1000);if(unit<=0||Math.abs(unit-Number(x.price)*1000)>0.001)return fail('سعر المنتج غير صالح');fils+=unit*qty;lines.push({product_id:x.id,quantity:qty,unit_price:Number(x.price)});}
  if(fils<=0||fils>100000000)return fail('قيمة الطلب غير صالحة');
  // Inventory is rechecked on the server. Production launch also requires atomic reservation / concurrency validation.
  const {data:order,error:oe}=await db.from('order_records').insert({status:'pending_payment',total:fils/1000,customer_name:name,customer_mobile:mobile,delivery_address:address}).select('id').single();
  if(oe||!order)return fail('تعذر إنشاء الطلب',500);
  const {error:le}=await db.from('order_lines').insert(lines.map(l=>({...l,order_id:order.id})));
  if(le){await db.from('order_records').update({status:'cancelled'}).eq('id',order.id);return fail('تعذر حفظ تفاصيل الطلب',500)}
  try{
   const methods=await mf('InitiatePayment',{InvoiceAmount:fils/1000,CurrencyIso:'KWD'});
   const method=methods?.PaymentMethods?.find((m:{IsDirectPayment?:boolean,PaymentMethodId:number})=>!m.IsDirectPayment)||methods?.PaymentMethods?.[0];
   if(!method)throw new Error('لا توجد وسيلة دفع مفعّلة');
   const origin=new URL(req.url).origin;
   const invoice=await mf('ExecutePayment',{PaymentMethodId:method.PaymentMethodId,InvoiceValue:fils/1000,CustomerName:name,CustomerMobile:mobile,MobileCountryCode:'+965',DisplayCurrencyIso:'KWD',Language:'AR',CustomerReference:order.id,CallBackUrl:`${origin}/payment-result?order=${order.id}`,ErrorUrl:`${origin}/payment-result?order=${order.id}`});
   await db.from('order_records').update({payment_invoice_id:String(invoice.InvoiceId)}).eq('id',order.id);
   return NextResponse.json({url:invoice.PaymentURL});
  }catch(e){await db.from('order_records').update({status:'cancelled'}).eq('id',order.id);return fail(e instanceof Error?e.message:'تعذر إنشاء رابط الدفع',502)}
 }catch{return fail('تعذر معالجة الطلب',500)}
}
