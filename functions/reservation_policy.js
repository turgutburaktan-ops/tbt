const MINUTE=60000,DAY=86400000;
const ms=value=>value?.toMillis?.()||Number(value)||0;
class PolicyError extends Error{}
function requireState(ok,message){if(!ok)throw new PolicyError(message);}
function transition(r,action,role,now,newAtMs){
 const at=ms(r.at),prep=r.preparationStatus||'awaiting_confirmation',started=!!r.preparationStartedAt;
 const open=['pending','accepted'].includes(r.status);
 if(['confirm','cancel','reschedule','dispute'].includes(action))requireState(role==='customer','Bu rezervasyon sana ait değil.');
 else requireState(role==='owner','İşletme sahibi gerekli.');
 if(action==='confirm'){
   requireState(r.status==='accepted'&&(r.orderItems||[]).length>0,'Onaylanmış siparişli rezervasyon gerekli.');
   requireState(now>=at-15*MINUTE&&now<at+30*MINUTE,'Hazırlık onayı rezervasyondan 15 dakika önce açılır; saatten 30 dakika sonra kapanır.');
   if(prep==='confirmed'||started)return {noop:true};
   requireState(prep==='awaiting_confirmation','Hazırlık onayı verilemiyor.');
   return {patch:{preparationStatus:'confirmed',preparationConfirmedAt:now},notify:'Müşteri hazırlığa onay verdi'};
 }
 if(action==='cancel'){
   if(r.status==='cancelled')return {noop:true};
   requireState(open&&!['completed','no_show'].includes(prep),'Bu rezervasyon iptal edilemiyor.');
   return {patch:{status:'cancelled',preparationStatus:'cancelled',cancelledAt:now},outcome:started?'cancelled':null,notify:started?'Müşteri hazırlık başladıktan sonra iptal etti':'Müşteri rezervasyonu iptal etti'};
 }
 if(action==='reschedule'){
   requireState(open&&!started,'Hazırlık başladıktan sonra saat değiştirilemez.');
   requireState(Number.isFinite(newAtMs)&&newAtMs>now&&newAtMs<=now+180*DAY,'Geçerli bir gelecek tarih seç.');
   requireState(newAtMs!==at,'Farklı bir saat seç.');
   return {patch:{status:'pending',at:newAtMs,preparationStatus:'awaiting_confirmation',preparationConfirmedAt:null,reminderSentAt:null,scheduleVersion:(r.scheduleVersion||0)+1},notify:'Müşteri saat değişikliği istedi; yeniden onay gerekli'};
 }
 if(action==='start'){
   requireState(r.status==='accepted','Onaylanmış rezervasyon gerekli.');
   if(started&&prep==='preparing')return {noop:true};
   requireState(r.status==='accepted'&&prep==='confirmed'&&!!r.preparationConfirmedAt,'Önce müşterinin hazırlık onayı gerekli.');
   requireState(now<at+30*MINUTE,'Hazırlığa başlama süresi geçti.');
   return {patch:{preparationStatus:'preparing',preparationStartedAt:now},outcome:'prepared',notify:'Siparişinin hazırlığı başladı'};
 }
 if(action==='ready'||action==='complete'){
   const next=action==='ready'?'ready':'completed';if(prep===next)return {noop:true};
   requireState(r.status==='accepted'&&started&&['preparing','ready'].includes(prep),'Hazırlığı başlayan sipariş gerekli.');
   return {patch:{preparationStatus:next},outcome:next==='completed'?'completed':null,notify:next==='ready'?'Siparişin hazır':'Siparişin tamamlandı'};
 }
 if(action==='no_show'){
   if(prep==='no_show')return {noop:true};
   requireState(r.status==='accepted'&&started&&r.preparationConfirmedAt&&['preparing','ready'].includes(prep),'Müşteri onayı ve başlayan hazırlık gerekli.');
   requireState(now>=at+30*MINUTE,'Gelmedi bildirimi rezervasyondan 30 dakika sonra açılır.');
   requireState(now<=at+7*DAY,'Gelmedi bildirimi için 7 günlük süre geçti.');
   return {patch:{preparationStatus:'no_show',incidentStatus:'reported',incidentReportedAt:now,incidentReviewAfter:now+3*DAY},outcome:'reported',notify:'İşletme gelmediğini bildirdi. Rezervasyonlarım bölümünden itiraz edebilirsin.'};
 }
 throw new PolicyError('Geçersiz işlem.');
}
function historySummary(rows,now){
 const eligible=rows.filter(r=>ms(r.preparedAt)>=now-90*DAY);
 return {prepared:eligible.length,cancelled:eligible.filter(r=>['cancelled','confirmed_cancelled'].includes(r.status)).length,noShows:eligible.filter(r=>r.status==='confirmed_no_show'||(r.status==='reported'&&ms(r.reviewAfter)<=now)).length};
}
module.exports={transition,historySummary,ms,MINUTE,DAY,PolicyError};
