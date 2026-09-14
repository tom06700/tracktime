import {createSculpture} from './sculptures.js';
import {createPortal} from './portal.js';
let portal;
const icon=n=>`<i data-lucide="${n}"></i>`;
const concepts=[
 {name:'Le passage',detail:'La porte reste entrouverte. Clique dessus ou sur Explorer : elle s’ouvre et tu passes de l’autre côté.',titles:['Un nouveau monde<br>t’attend.','Une autre porte<br>à ouvrir.','La suite peut<br>attendre.']},
 {name:'Le rendez-vous',detail:'Les anneaux s’écartent, les satellites se croisent, puis l’ensemble se réaligne.',titles:['Trouve ton prochain<br>coup de cœur.','Pas encore<br>la bonne rencontre.','Tout est<br>à sa place.']},
 {name:'Le fil des histoires',detail:'Le ruban se déploie, tourne sur lui-même et retrouve sa forme. Une boucle sans coupure.',titles:['Chaque histoire<br>a un début.','Une autre piste<br>à suivre.','Tu as gardé<br>le fil.']}
];
const descriptions=['Ajoute une série pour retrouver<br>ici tes prochains épisodes.','Aucun titre ne correspond à ta recherche.<br>Essaie avec un autre nom.','Tu as vu tous les épisodes disponibles.<br>On se retrouve pour la suite.'];
const buttonLabels=['Explorer les séries','Modifier la recherche','Découvrir une autre série'];
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
let mode=0,playing=!reduced.matches,speed=1,last=performance.now(),frames=[];
const gallery=document.querySelector('#gallery');
gallery.innerHTML=concepts.map((c,i)=>`<article><div class="heading"><small>0${i+1}</small><h2>${c.name}</h2></div><div class="viewport"><div class="phone"><div class="status"><b>9:41</b><span>${icon('signal')}${icon('wifi')}${icon('battery-full')}</span></div><div class="brand"><img src="assets/wordmark.svg" alt="Nitrate"><button class="bell" aria-label="Notifications">${icon('bell')}</button></div><h2 class="section-title">Séries <span>À voir</span></h2><div class="stage" tabindex="0" role="button" aria-label="${i===0?'Traverser la porte vers Explorer':'Rejouer '+c.name}"><span class="stage-label">${i===0?'ENTRE, TOUT COMMENCE ICI':'TOUCHER POUR ANIMER'}</span></div><div class="copy"><h3></h3><p></p><button class="primary"></button><div class="caption">Une place pour tes prochaines découvertes.</div></div><nav class="nav" aria-label="Contexte de l’application"><div class="active">${icon('tv-minimal')}Séries</div><div>${icon('clapperboard')}Films</div><div>${icon('compass')}Explorer</div><div>${icon('user-round')}Profil</div></nav><div class="home"></div></div></div><p class="notes">${c.detail}</p><div class="timeline"><button aria-label="Rejouer la scène ${i+1}">Rejouer</button><input type="range" min="0" max="7" value="2.8" step=".01" aria-label="Position de l’animation ${i+1}"><output>2,8 s</output></div></article>`).join('');
const articles=[...gallery.children];
function icons(){lucide.createIcons();}
function playback(){document.querySelector('#play').textContent=playing?'Mettre en pause':'Reprendre';}
function notice(i,text){const p=articles[i].querySelector('.phone');p.querySelector('.notice')?.remove();const n=document.createElement('div');n.className='notice';n.role='status';n.textContent=text;p.append(n);setTimeout(()=>n.remove(),2400);}
function primary(i){
 if(i===0){portal.start();return;}
 if(mode!==1){setMode(1);return;}
 const copy=articles[i].querySelector('.copy');
 copy.innerHTML='<h3>Que cherches-tu ?</h3><label class="query-label">Titre de la série<input class="query" placeholder="Une série, un univers…" aria-label="Titre à rechercher"></label><button class="primary search-submit">Rechercher '+icon('arrow-up-right')+'</button>';
 const submit=()=>{setMode(1);notice(i,'Recherche de démonstration terminée.');};
 copy.querySelector('.query').focus();copy.querySelector('.query').onkeydown=e=>{if(e.key==='Enter')submit();};copy.querySelector('.search-submit').onclick=submit;icons();
}
function setMode(next){
 portal?.reset({focus:false});
 mode=next;document.querySelectorAll('[data-mode]').forEach(b=>{b.classList.toggle('selected',+b.dataset.mode===mode);b.setAttribute('aria-pressed',String(+b.dataset.mode===mode));});
 articles.forEach((a,i)=>{
  const copy=a.querySelector('.copy');
  copy.innerHTML=`<h3>${concepts[i].titles[mode]}</h3><p>${descriptions[mode]}</p><button class="primary">${buttonLabels[mode]}${icon(mode===1?'search':'arrow-up-right')}</button><div class="caption">${['Une place pour tes prochaines découvertes.','Essaie le titre original ou une autre orthographe.','Les nouveautés apparaîtront ici.'][mode]}</div>`;
  copy.querySelector('.primary').onclick=()=>primary(i);
  a.querySelector('.section-title').innerHTML=['Séries <span>À voir</span>','Recherche <span>Aucun résultat</span>','À venir <span>Tout est vu</span>'][mode];
  a.classList.remove('mode-change');void a.offsetWidth;a.classList.add('mode-change');if(frames[i]){frames[i].time=reduced.matches?2.8:0;frames[i].dirty=true;}
 });icons();
}
articles.forEach((a,i)=>{
 new ResizeObserver(([e])=>a.querySelector('.phone').style.setProperty('--scale',e.contentRect.width/390)).observe(a.querySelector('.viewport'));
 const stage=a.querySelector('.stage');let sculpture;
 try{sculpture=createSculpture(stage,i);}catch(e){const n=document.createElement('p');n.className='error';n.textContent='Le rendu 3D n’a pas pu démarrer dans ce navigateur.';stage.append(n);console.error(e);return;}
 const frame={sculpture,time:2.8,dirty:true,range:a.querySelector('input'),output:a.querySelector('output')};frames[i]=frame;
 const replay=()=>{if(i===0)portal?.reset({focus:false});frame.time=reduced.matches?2.8:0;frame.dirty=true;if(!reduced.matches){playing=true;playback();}};
 if(i===0)portal=createPortal(a,frame,{mode:()=>mode,speed:()=>speed,reduced,icons});
 const activate=()=>{if(i===0)portal.start();else replay();};
 stage.onclick=activate;stage.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();activate();}};a.querySelector('.timeline button').onclick=replay;
 frame.range.oninput=e=>{playing=false;playback();frame.time=+e.target.value;frame.dirty=true;};

 a.querySelector('.bell').onclick=()=>notice(i,'Aucune notification pour le moment.');
});
setMode(0);frames.forEach(f=>f.time=2.8);icons();playback();
document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>setMode(+b.dataset.mode));
document.querySelector('#size').onclick=e=>{const large=document.body.classList.toggle('large');e.currentTarget.textContent=large?'Vue d’ensemble':'Agrandir';};
document.querySelector('#play').onclick=()=>{playing=!playing;playback();};
document.querySelector('#speed').onclick=e=>{speed=speed===1?.35:1;e.currentTarget.textContent=speed===1?'Vitesse ×1':'Ralenti ×0,35';};
document.querySelector('#replay').onclick=()=>{portal?.reset({focus:false});frames.forEach(f=>{f.time=reduced.matches?2.8:0;f.dirty=true;});playing=!reduced.matches;playback();};
reduced.addEventListener('change',e=>{if(e.matches){playing=false;frames.forEach(f=>{f.time=2.8;f.dirty=true;});playback();}});
function tick(now){requestAnimationFrame(tick);const dt=Math.min((now-last)/1000,.05);last=now;if(document.hidden)return;portal?.tick(dt);frames.forEach((f,i)=>{if(i>0&&document.body.classList.contains('single'))return;if(i===0&&portal?.active)return;if(playing)f.time=(f.time+dt*speed)%7;if(playing||f.dirty||f.sculpture.needsRender())f.sculpture.draw(f.time,mode,!playing);f.range.value=f.time;f.output.textContent=f.time.toFixed(1).replace('.',',')+' s';f.dirty=false;});}
requestAnimationFrame(tick);

document.querySelector('#isolate').onclick=e=>{const single=document.body.classList.toggle('single');e.currentTarget.textContent=single?'Voir les 3 pistes':'Isoler le passage';};
