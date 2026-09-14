// Original adaptation of the movement principles cited in SOURCES.md.
export const mix=(a,b,t)=>a+(b-a)*t;
const clamp=t=>Math.max(0,Math.min(1,t));
const smooth=t=>t*t*(3-2*t);
const expo=t=>t===0?0:t===1?1:t<.5?Math.pow(2,20*t-10)/2:(2-Math.pow(2,-20*t+10))/2;
const spring=t=>{const z=.84,w=12,b=Math.sqrt(1-z*z);return 1-Math.exp(-z*w*t)*(Math.cos(w*b*t)+z/b*Math.sin(w*b*t))};
export function posterFrame(width,height,index){const tile=Math.max(width,height*2/3);return{backgroundSize:`${tile*3}px ${tile*1.5}px`,backgroundPosition:`${(width-tile)/2-(index%3)*tile}px ${(height-tile*1.5)*.36}px`}}
export function sample(kind,a,b,t,{index=0,focus=0,viewport=390}={}){
 if(t<=0)return{...a,rotation:0};if(t>=1)return{...b,rotation:0};
 let p=kind==='cascade-soft'?(1-Math.cos(Math.PI*t))/2:kind.startsWith('cascade')?expo(t):spring(t);let x=mix(a.left,b.left,p),y=mix(a.top,b.top,p),w=mix(a.width,b.width,p),h=mix(a.height,b.height,p),radius=mix(a.radius,b.radius,clamp(p)),rotation=0;
 if(kind==='cascade-depth'){
   const lift=Math.sin(Math.PI*clamp(p));
   const scale=1-.065*lift;
   x+=w*(1-scale)/2; y+=h*(1-scale)/2-12*lift;
   w*=scale;h*=scale;rotation=(index%2===0?-.75:.75)*lift;
 }else if(kind==='arc'){
   const amount=Math.sin(Math.PI*clamp(p));
   const direction=index%2===0?-1:1;
   const bend=Math.min(28,Math.hypot(b.left-a.left,b.top-a.top)*.08);
   x+=direction*bend*amount;
   y-=amount*(index===focus?6:12);
   rotation=direction*1.5*amount;
 }else if(kind==='stack'){
   const rank=(index-focus+6)%6;
   const middle={left:(viewport-112)/2+rank*3,top:130+rank*5,width:112,height:168,radius:16};
   if(t<.4){p=smooth(t/.4);x=mix(a.left,middle.left,p);y=mix(a.top,middle.top,p);w=mix(a.width,middle.width,p);h=mix(a.height,middle.height,p);radius=mix(a.radius,16,p);rotation=mix(0,(rank-2)*2.1,p)}
   else {p=1-Math.pow(1-(t-.4)/.6,4);x=mix(middle.left,b.left,p);y=mix(middle.top,b.top,p);w=mix(middle.width,b.width,p);h=mix(middle.height,b.height,p);radius=mix(16,b.radius,p);rotation=mix((rank-2)*2.1,0,p)}
 }
 return{left:x,top:y,width:Math.max(1,w),height:Math.max(1,h),radius,rotation};
}
export function frames(kind,a,b,options={}){return Array.from({length:81},(_,i)=>{const t=i/80,r=sample(kind,a,b,t,options);return{offset:t,transform:`translate(${r.left-b.left}px,${r.top-b.top}px) rotate(${r.rotation}deg)`,width:`${r.width}px`,height:`${r.height}px`,borderRadius:`${r.radius}px`,...posterFrame(r.width,r.height,options.index||0),...(kind==='cascade-depth'?{filter:`blur(${Math.sin(Math.PI*t)*1.8}px) brightness(${1-.1*Math.sin(Math.PI*t)})`,boxShadow:`0 ${Math.sin(Math.PI*t)*12}px ${Math.sin(Math.PI*t)*24}px rgba(0,0,0,.28)`}:{})}})}
