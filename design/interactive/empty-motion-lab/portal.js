import {ease} from './sculptures.js';
const icon=n=>`<i data-lucide="${n}"></i>`;
const titles=[{name:'Severance',genre:'Science-fiction · Série',art:'severance.jpg'},{name:'The Last of Us',genre:'Drame · Série',art:'the-last-of-us.jpg'},{name:'Shōgun',genre:'Historique · Série',art:'shogun.jpg'}];
const duration=2.2;
export function createPortal(article,frame,{mode,speed,reduced,icons}){
 const phone=article.querySelector('.phone'),stage=article.querySelector('.stage');
 const original=[...phone.children].filter(e=>e!==stage);
 const destination=document.createElement('section');destination.className='portal-destination';destination.hidden=true;destination.inert=true;
 destination.setAttribute('aria-label','Explorer — aperçu interactif');
 destination.innerHTML=`<div class="explorer-world"><div class="status"><b>9:41</b><span>${icon('signal')}${icon('wifi')}${icon('battery-full')}</span></div><div class="brand"><img src="assets/wordmark.svg" alt="Nitrate"><button class="back-door" aria-label="Revenir à la porte">${icon('arrow-left')}</button></div><div class="explorer-scroll"><p class="explorer-eyebrow">EXPLORER</p><h2 tabindex="-1">Que regarder ce soir ?</h2><label class="explorer-search">${icon('search')}<input placeholder="Un film, une série, un animé…" aria-label="Rechercher dans les titres de démonstration"></label><div class="explorer-filters" aria-label="Type de titre">${['Tout','Séries','Films','Animés'].map((t,i)=>`<button class="${i===0?'selected':''}" aria-pressed="${i===0}">${t}</button>`).join('')}</div><div class="discovery-content"><div class="discovery-heading"><h3>À découvrir</h3><span>La sélection</span></div><div class="explorer-hero"><img src="assets/severance.jpg" alt="Affiche de Severance"><div class="hero-shade"></div><div class="hero-copy"><span>LE MYSTÈRE COMMENCE ICI</span><h3>Severance</h3><p>Et si ta vie avait deux faces ?</p><button class="discover-title">Découvrir ${icon('arrow-up-right')}</button></div></div><div class="discovery-heading"><h3>D’autres univers</h3>${icon('arrow-right')}</div><div class="discovery-cards"></div></div><p class="catalogue-note">Sélection de démonstration · aperçu de transition</p></div><nav class="nav" aria-label="Navigation de l’aperçu"><button class="back-door">${icon('tv-minimal')}Séries</button><div>${icon('clapperboard')}Films</div><div class="active">${icon('compass')}Explorer</div><div>${icon('user-round')}Profil</div></nav><div class="home"></div></div><div class="portal-warmth"></div>`;
 phone.append(destination);
 const world=destination.querySelector('.explorer-world');
 const controls=document.createElement('div');controls.className='portal-controls';
 controls.innerHTML='<div><span>LA TRAVERSÉE</span><button class="return-door">Retour à la porte</button></div><div class="timeline"><button class="portal-play">Traverser</button><input type="range" min="0" max="2.2" step=".01" value="0" aria-label="Position de la traversée du portail"><output>0,0 s</output></div>';
 article.append(controls);
 const range=controls.querySelector('input'),out=controls.querySelector('output'),play=controls.querySelector('.portal-play');
 let state='idle',time=0,running=false,loopTime=0;
 function results(){
  const q=destination.querySelector('input').value.trim().toLocaleLowerCase('fr');
  const filter=destination.querySelector('.explorer-filters .selected').textContent;
  const items=(filter==='Tout'||filter==='Séries')?titles.filter(t=>t.name.toLocaleLowerCase('fr').includes(q)):[];
  destination.querySelector('.explorer-hero').hidden=!!q||!items.length;
  destination.querySelector('.discovery-cards').innerHTML=items.length?items.map(t=>`<button class="discovery-card" data-title="${t.name}"><img src="assets/${t.art}" alt=""><strong>${t.name}</strong><span>${t.genre}</span></button>`).join(''):'<p class="no-demo-result">Aucun titre correspondant dans cet aperçu.</p>';
  destination.querySelectorAll('.discovery-card').forEach(b=>b.onclick=()=>details(b.dataset.title));
 }
 function details(name){
  destination.querySelector('.preview-detail')?.remove();
  const item=titles.find(t=>t.name===name),panel=document.createElement('div');panel.className='preview-detail';panel.innerHTML=`<button aria-label="Fermer la fiche">${icon('x')}</button><img src="assets/${item.art}" alt="Affiche de ${item.name}"><h3>${item.name}</h3><p>${item.genre}</p><small>Fiche de démonstration</small>`;world.append(panel);panel.querySelector('button').onclick=()=>panel.remove();icons();panel.querySelector('button').focus();
 }
 destination.querySelector('input').oninput=results;
 destination.querySelectorAll('.explorer-filters button').forEach(b=>b.onclick=()=>{destination.querySelectorAll('.explorer-filters button').forEach(x=>{x.classList.toggle('selected',x===b);x.setAttribute('aria-pressed',String(x===b));});results();});
 destination.querySelector('.discover-title').onclick=()=>details('Severance');
 destination.addEventListener('pointerdown',e=>{if(!e.target.closest('input'))destination.querySelector('input').blur();});
 function ui(){range.value=time;out.textContent=time.toFixed(1).replace('.',',')+' s';play.textContent=state==='arrived'?'Rejouer':running?'Pause':state==='idle'?'Traverser':'Reprendre';}
 function prepare(){
  if(state!=='idle')return;
  loopTime=frame.time;frame.sculpture.beginPortal(loopTime,mode());
  original.forEach(e=>e.inert=true);stage.inert=true;
  phone.classList.add('portal-active');destination.hidden=false;destination.inert=true;
  state='entering';time=0;
 }
 function render(){
  if(state==='idle')return;
  const t=time,pose=frame.sculpture.portalFrame(Math.min(t,1.9));
  destination.style.clipPath=t>=1.86?'none':pose.clip;
  destination.style.opacity=reduced.matches?'1':String(ease(.18,.65,t));
  // The same Explorer surface is revealed behind the arch and settles in place.
  world.style.transform=`scale(${1.10-.10*ease(.6,2.2,t)}) translateY(${14*(1-ease(.6,2.2,t))}px)`;
  world.style.filter=`blur(${3.5*(1-ease(.35,1.6,t))}px)`;
  destination.querySelector('.portal-warmth').style.opacity=String(.18*Math.sin(Math.PI*ease(.25,2.05,t)));
  const fade=1-ease(0,.42,t);original.forEach(e=>{e.style.opacity=fade;e.style.transform=`translateY(${8*(1-fade)}px)`;});
  stage.style.opacity=String(1-ease(1.78,1.95,t));
  if(t>=duration){state='arrived';running=false;destination.inert=false;stage.hidden=true;phone.classList.add('portal-arrived');}
  else{state='entering';destination.inert=true;stage.hidden=false;phone.classList.remove('portal-arrived');}
  ui();
 }
 function start(){
  if(state!=='idle')return;
  prepare();running=true;
  if(reduced.matches){time=duration;render();destination.querySelector('h2').focus({preventScroll:true});}
  else render();
 }
 function reset({focus=true}={}){
  state='idle';running=false;time=0;frame.sculpture.resetPortal();
  frame.time=loopTime||frame.time;frame.dirty=true;
  phone.classList.remove('portal-active','portal-arrived');destination.hidden=true;destination.inert=true;
  destination.querySelector('.preview-detail')?.remove();destination.querySelector('.explorer-scroll').scrollTop=0;
  original.forEach(e=>{e.inert=false;e.style.opacity='';e.style.transform='';});stage.inert=false;stage.hidden=false;stage.style.opacity='';
  ui();if(focus)stage.focus({preventScroll:true});
 }
 play.onclick=()=>{if(state==='idle')start();else if(state==='arrived'){reset({focus:false});start();}else{running=!running;ui();}};
 range.oninput=()=>{prepare();running=false;time=+range.value;render();};
 controls.querySelector('.return-door').onclick=()=>reset();
 destination.querySelectorAll('.back-door').forEach(b=>b.onclick=()=>reset());
 phone.addEventListener('keydown',e=>{if(e.key==='Escape'&&state!=='idle'){e.preventDefault();reset();}});
 reduced.addEventListener('change',()=>{if(reduced.matches&&state==='entering'){time=duration;render();}});
 results();icons();ui();
 return {start,reset, get active(){return state!=='idle';},tick(dt){if(!running)return;time=Math.min(duration,time+dt*speed());render();if(state==='arrived')destination.querySelector('h2').focus({preventScroll:true});}};
}
