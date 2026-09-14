'use strict';
const variants = [
  {name:'Cascade précise',text:'Une vague de bas en haut. Les titres suivent les lignes, puis les statuts terminent le mouvement.',timing:'800 ms · décalage 56 ms',badge:'Mon choix'},
  {name:'Révélation masquée',text:'Le numéro pose le repère. Le titre se déroule, puis le statut et la coche prennent leur place.',timing:'800 ms · décalage 44 ms',badge:''},
  {name:'Fondu continu',text:'Chaque emplacement laisse progressivement apparaître son épisode, dans une vague de lumière douce.',timing:'720 ms · décalage 44 ms',badge:'Le plus discret'},
];
const data = [
 ['Le départ','Une nouvelle rencontre','La promesse','Les retrouvailles','Au-delà de la frontière','Le choix'],
 ['Un nouveau cap','L’autre rive','Le signal','À contre-courant','Le dernier passage','L’aube'],
];
const check='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="m6 12 4 4 8-8"/></svg>';
const root=document.querySelector('.proposals');
root.innerHTML=variants.map((v,i)=>`<article data-variant="${i}"><div class="heading"><span class="index">0${i+1}</span><h2>${v.name}</h2><span class="badge">${v.badge}</span></div><div class="screen"><div class="app-header"><span class="back" aria-hidden="true">‹</span>One Piece<span class="season-count">Aperçu · 6 épisodes</span></div><div class="tabs"><span>Aperçu</span><span class="active">Épisodes</span></div><div class="controls"><div class="season-line"><select aria-label="Saison · ${v.name}"><option value="0">Saison 1</option><option value="1">Saison 2</option></select><span class="small-action">Tout marquer vu</span></div><span class="filter active">Tous</span><span class="filter">Non vus</span><span class="jump" aria-hidden="true">⌕</span></div><div class="list" aria-label="Épisodes de démonstration"><div class="rows"></div></div><div class="app-foot">Ta progression reste entre tes mains.</div></div><p class="description">${v.text}</p><div class="meta"><button class="replay" aria-label="Rejouer ${v.name}">↻ &nbsp; Rejouer</button><span class="timing">${v.timing}</span></div><div class="progress" aria-hidden="true"><span></span></div></article>`).join('');
const cards=[...root.children];
const states=cards.map(()=>({generation:0,animations:[],season:0}));
const slow=document.querySelector('#slow');
const fast=document.querySelector('#fast');
const reduced=document.querySelector('#reduced');
const preference=matchMedia('(prefers-reduced-motion: reduce)');
reduced.checked=preference.matches;
preference.addEventListener('change',e=>{reduced.checked=e.matches;cards.forEach((_,i)=>run(i));});
function rows(season){return data[season].map((name,j)=>`<div class="episode"><span class="number">${j+1}</span><div class="copy"><span class="title">${name}</span><span class="status">${j<2?'Vu':'À découvrir'}</span></div><span class="check ${j<2?'seen':''}">${check}</span></div>`).join('');}
function placeholder(){return `<div class="skeleton" aria-hidden="true">${data[0].map((_,j)=>`<div class="episode"><span class="number"></span><div class="copy"><span class="bone" style="width:${65+j%3*12}%"></span><span class="bone short"></span></div><span class="check"></span></div>`).join('')}</div>`;}
function animate(i,element,keyframes,duration,delay=0){const a=element.animate(keyframes,{duration:duration*(slow.checked?3:1),delay:delay*(slow.checked?3:1),easing:fast.checked?'cubic-bezier(.22,1,.36,1)':'cubic-bezier(.2,.75,.2,1)',fill:'both'});states[i].animations.push(a);return a;}
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function run(i,mode='replay'){
 const card=cards[i],state=states[i],list=card.querySelector('.list'),content=card.querySelector('.rows');
 const generation=++state.generation;
 const original=fast.checked;
 card.querySelector('.timing').textContent=original?['440 ms · décalage 28 ms','460 ms · décalage 20 ms','310 ms · décalage 18 ms'][i]:variants[i].timing;
 state.animations.forEach(a=>a.cancel());state.animations=[];
 list.querySelectorAll('.skeleton').forEach(e=>e.remove());
 content.style.opacity='1';list.setAttribute('aria-busy','false');
 if(mode==='season'&&!reduced.checked){
   const exitDuration=original?100:180;
   animate(i,content,[{opacity:1,transform:'translateY(0)'},{opacity:0,transform:`translateY(${original?0:-4}px)`}],exitDuration);
   await pause(exitDuration*(slow.checked?3:1));if(state.generation!==generation)return;
   state.animations.forEach(a=>a.cancel());state.animations=[];
 }
 content.innerHTML=rows(state.season);
 if(mode==='load'){
   content.style.opacity='0';list.setAttribute('aria-busy','true');list.insertAdjacentHTML('beforeend',placeholder());
   if(!reduced.checked)list.querySelector('.skeleton').classList.add('pulse');
   await pause(600);if(state.generation!==generation)return;
   list.querySelector('.skeleton').classList.remove('pulse');
 }
 if(reduced.checked){content.style.opacity='1';list.querySelectorAll('.skeleton').forEach(e=>e.remove());list.setAttribute('aria-busy','false');return;}
 if(i===2&&!list.querySelector('.skeleton')&&mode!=='season')list.insertAdjacentHTML('beforeend',placeholder());
 const sk=list.querySelector('.skeleton');
 if(sk){
   const fades=[...sk.children].map((row,j)=>animate(i,row,[{opacity:1},{opacity:0}],original?(i===2?250:120):(i===2?460:220),original?0:j*(i===0?56:44)));
   Promise.all(fades.map(a=>a.finished)).then(()=>{if(state.generation===generation)sk.remove();}).catch(()=>{});
 }
 content.style.opacity='1';list.setAttribute('aria-busy','false');
 [...content.children].forEach((row,j)=>{
   if(i===0&&original)animate(i,row,[{opacity:0,transform:'translateY(12px)'},{opacity:1,transform:'translateY(0)'}],300,j*28);
   if(i===0&&!original){
     const start=j*56;
     animate(i,row,[{opacity:0,transform:'translateY(20px)'},{opacity:1,transform:'translateY(0)'}],520,start);
     animate(i,row.querySelector('.title'),[{opacity:0,transform:'translateY(4px)'},{opacity:1,transform:'translateY(0)'}],400,start+45);
     animate(i,row.querySelector('.status'),[{opacity:0},{opacity:1}],320,start+110);
   }
   if(i===1&&original){
     animate(i,row.querySelector('.number'),[{opacity:0},{opacity:1}],180,j*20);
     animate(i,row.querySelector('.copy'),[{clipPath:'inset(100% 0 0 0)',transform:'translateY(10px)'},{clipPath:'inset(0% 0 0 0)',transform:'translateY(0px)'}],360,j*20);
     animate(i,row.querySelector('.check'),[{opacity:0,transform:'scale(.9)'},{opacity:1,transform:'scale(1)'}],230,55+j*20);
   }
   if(i===1&&!original){
     const start=j*44;
     animate(i,row.querySelector('.number'),[{opacity:0,transform:'translateY(5px)'},{opacity:1,transform:'translateY(0)'}],390,start);
     animate(i,row.querySelector('.title'),[{clipPath:'inset(0 0 100% 0)',transform:'translateY(14px)'},{clipPath:'inset(0 0 0% 0)',transform:'translateY(0)'}],510,start+70);
     animate(i,row.querySelector('.status'),[{opacity:0,transform:'translateY(5px)'},{opacity:1,transform:'translateY(0)'}],360,start+160);
     animate(i,row.querySelector('.check'),[{opacity:0,transform:'scale(.92)'},{opacity:1,transform:'scale(1)'}],370,start+140);
   }
   if(i===2)animate(i,row,[{opacity:0},{opacity:1}],original?220:500,j*(original?18:44));
 });
 animate(i,card.querySelector('.progress span'),[{transform:'scaleX(0)'},{transform:'scaleX(1)'}],(original?[440,460,310]:[800,800,720])[i]);
}
cards.forEach((card,i)=>{card.querySelector('.replay').addEventListener('click',()=>run(i));card.querySelector('select').addEventListener('change',e=>{states[i].season=Number(e.target.value);run(i,'season');});});
document.querySelector('#all').addEventListener('click',()=>cards.forEach((_,i)=>run(i)));
document.querySelector('#load').addEventListener('click',()=>cards.forEach((_,i)=>run(i,'load')));
slow.addEventListener('change',()=>cards.forEach((_,i)=>run(i)));
fast.addEventListener('change',()=>cards.forEach((_,i)=>run(i)));
reduced.addEventListener('change',()=>cards.forEach((_,i)=>run(i)));
cards.forEach((_,i)=>{cards[i].querySelector('.rows').innerHTML=rows(0);});
setTimeout(()=>cards.forEach((_,i)=>run(i,'load')),400);
