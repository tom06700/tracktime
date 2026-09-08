import {frames} from './motion.mjs';
const icon=name=>`<i data-lucide="${name}"></i>`;
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
const duration=()=>reduced.matches?0:document.querySelector('#slow').checked?1900:640;
const easing='cubic-bezier(.22,1,.36,1)';
// Crop the existing poster atlas uniformly: never stretch its subjects.
function posterFrame(width,height,index){const tile=Math.max(width,height*2/3);return{backgroundSize:`${tile*3}px ${tile*1.5}px`,backgroundPosition:`${(width-tile)/2-(index%3)*tile}px ${(height-tile*1.5)*.36}px`}}
const series=[['La dernière lumière','S02 · E04','Le passage'],['Les jours suspendus','S01 · E06','L’autre rive'],['Au-delà des étoiles','S03 · E02','Le signal'],['Le silence des montagnes','S01 · E03','Le refuge'],['L’heure bleue','S02 · E08','Les retrouvailles'],['Après la nuit','S01 · E05','Les absents']];
const movies=[['La dernière lumière','2024','1 h 58 · Drame'],['Les jours suspendus','2025','2 h 04 · Aventure'],['Au-delà des étoiles','2023','1 h 46 · Science-fiction'],['Le silence des montagnes','2024','1 h 52 · Drame'],['L’heure bleue','2025','1 h 42 · Drame'],['Après la nuit','2024','2 h 08 · Thriller']];
const states=[];
const storage={get(k){try{return localStorage.getItem(k)}catch{return null}},set(k,v){try{localStorage.setItem(k,v)}catch{}}};
function build(type,data,variant){
 const seriesMode=type==='series';
 const s={type,data,variant,selected:0,compact:false,busy:false,seen:new Set(),animations:[]};
 states.push(s);
 const section=document.createElement('section');section.innerHTML=`<div class="label"><b>${variant.name}${variant.id==='arc'?'<em>Mon choix</em>':''}</b><span>${variant.subtitle}</span></div><button class="try">${icon('play')}Tester cette transition</button><div class="phone ${type}" aria-label="${variant.name}"><div class="library"><div class="status"><span>9:41</span>${icon('battery-full')}</div><div class="app-head"><img class="brand" src="../action-menus/assets/wordmark.svg" alt="Nitrate"><span aria-label="Collection">${seriesMode?icon('library-big'):'<img class="collection" src="../action-menus/assets/films-seen.svg" alt="Films vus">'}</span><span style="margin-left:12px" aria-label="Notifications">${icon('bell')}</span></div><div class="tabs" aria-hidden="true"><span class="active">${seriesMode?'À voir':'Ma liste'}</span><span>${seriesMode?'À venir':'Sorties'}</span></div><div class="heading"><div><h2>${seriesMode?'À reprendre.':'Ta prochaine séance.'}</h2><p>${seriesMode?'6 séries dans ta rotation.':'6 films à découvrir.'}</p></div><div class="view-toggle" role="group" aria-label="Disposition ${variant.name}"><button data-layout="large" aria-label="Grande carte · ${variant.name}" title="${seriesMode?'Grande carte':'Grandes affiches'}">${icon(seriesMode?'panel-top':'columns-2')}</button><button data-layout="compact" aria-label="Vue d’ensemble · ${variant.name}" title="Vue d’ensemble">${icon('grid-2x2')}</button></div></div><div class="scroller"><div class="stage"></div></div><nav class="nav" aria-label="Navigation illustrative">${[['tv','Séries'],['clapperboard','Films'],['scan-search','Explorer'],['user-round','Profil']].map(([i,t],idx)=>`<button tabindex="-1" aria-disabled="true" class="${idx===(seriesMode?0:1)?'active':''}">${icon(i)}<span>${t}</span></button>`).join('')}</nav></div><section class="detail" role="dialog" aria-modal="true" aria-label="Fiche" hidden></section><div class="toast" role="status" hidden></div></div><p class="caption">${variant.description}</p><a class="source-link" href="${variant.url}" target="_blank" rel="noreferrer">${variant.source} ↗</a><span class="step">${variant.steps}</span>`;
 document.querySelector('#previews').append(section);s.section=section;s.phone=section.querySelector('.phone');section.querySelector('.try').onclick=()=>setLayout(s,!s.compact);s.stage=section.querySelector('.stage');s.scroll=section.querySelector('.scroller');s.library=section.querySelector('.library');s.detail=section.querySelector('.detail');
 s.cards=data.map(([title,meta],i)=>{const el=document.createElement('article');el.className='card';el.dataset.id=i;el.style.setProperty('--position',`${i%3*50}%`);el.innerHTML=`<button class="art" aria-label="Ouvrir ${title}"><span class="watched">${icon(seriesMode?'play':'check')} ${seriesMode?meta:'Vu'}</span><span class="cinema-copy"><b>${title}</b><small>${meta} · ${data[i][2]}</small></span></button><h3 class="card-title">${title}</h3><p class="card-meta">${seriesMode?meta:meta+' · '+data[i][2]}</p>`;el.querySelector('.art').onclick=()=>openDetail(s,i);s.stage.append(el);return el});
 if(seriesMode){s.extras=document.createElement('div');s.extras.innerHTML=`<div class="hero-actions"><button class="open">${icon('arrow-up-right')}Ouvrir l’épisode</button><button class="seen">${icon('check')}Marquer vu</button></div><div class="rotation"><button class="prev" aria-label="Série précédente">${icon('arrow-left')}</button><span></span><button class="next" aria-label="Série suivante">${icon('arrow-right')}</button></div><div class="rail-label">Dans ta rotation</div>`;s.stage.append(s.extras);s.extras.querySelector('.prev').onclick=()=>rotate(s,-1);s.extras.querySelector('.next').onclick=()=>rotate(s,1);s.extras.querySelector('.open').onclick=()=>openDetail(s,s.selected);s.extras.querySelector('.seen').onclick=()=>mark(s,s.selected);}
 section.querySelectorAll('[data-layout]').forEach(b=>b.onclick=()=>setLayout(s,b.dataset.layout==='compact'));
 s.phone.addEventListener('keydown',e=>{if(e.key==='Escape'&&!s.detail.hidden)closeDetail(s);if(e.key==='Tab'&&!s.detail.hidden){const a=[...s.detail.querySelectorAll('button')];if(e.shiftKey&&document.activeElement===a[0]){e.preventDefault();a.at(-1).focus()}else if(!e.shiftKey&&document.activeElement===a.at(-1)){e.preventDefault();a[0].focus()}}});
 layout(s);return s;
}
function layout(s){const w=s.stage.clientWidth,pad=20,gap=s.compact?11:13;const cols=s.type==='series'?2:s.compact?3:2;const width=(w-pad*2-gap*(cols-1))/cols;let bottom=0;
 s.phone.classList.toggle('compact',s.compact);s.phone.querySelectorAll('[data-layout]').forEach(b=>b.setAttribute('aria-pressed',(b.dataset.layout==='compact')===s.compact));
 s.cards.forEach((el,i)=>{let x,y,cw,ph;const rank=(i-s.selected+s.cards.length)%s.cards.length;const cinema=s.type==='series'&&!s.compact;const hero=cinema&&rank===0;
 if(cinema){cw=hero?w-40:112;ph=hero?Math.round(cw*.89):164;x=hero?20:20+(rank-1)*125;y=hero?0:Math.round((w-40)*.89)+163;}
 else{cw=width;ph=width*1.5;x=pad+(i%cols)*(width+gap);y=Math.floor(i/cols)*(ph+(s.type==='series'?69:s.compact?68:81));}
 Object.assign(el.style,{width:`${cw}px`,height:`${ph+64}px`,transform:`translate(${x}px,${y}px)`});el.dataset.x=x;el.dataset.y=y;
 const art=el.querySelector('.art');art.style.height=`${ph}px`;art.style.borderRadius=hero?'27px':s.compact?'14px':'18px';Object.assign(art.style,posterFrame(cw,ph,i));
 el.querySelector('.cinema-copy').hidden=!hero;el.querySelector('.watched').hidden=hero;
 const title=el.querySelector('.card-title'),meta=el.querySelector('.card-meta');title.hidden=hero;meta.hidden=hero;title.style.top=`${ph+9}px`;meta.style.top=`${ph+43}px`;meta.textContent=s.type==='series'?s.data[i][2]:s.compact?s.data[i][1]:s.data[i][1]+' · '+s.data[i][2];
 el.style.zIndex=hero?2:1;const visible=!cinema||rank<4;el.inert=!visible;el.setAttribute('aria-hidden',!visible);bottom=Math.max(bottom,y+ph+85);
 });
 if(s.extras){s.extras.hidden=s.compact;const h=Math.round((w-40)*.89);const actions=s.extras.querySelector('.hero-actions');Object.assign(actions.style,{top:`${h+12}px`,left:'20px',width:`${w-40}px`});s.extras.querySelector('.rotation').style.top=`${h+69}px`;s.extras.querySelector('.rotation span').textContent=`À l’affiche · ${s.selected+1} / ${s.cards.length}`;s.extras.querySelector('.rail-label').style.top=`${h+134}px`;}
 s.stage.style.height=`${bottom+95}px`;
}
async function morph(s,change){
 if(s.busy||!s.detail.hidden)return;
 s.busy=true;s.phone.classList.add('busy');
 const factor=reduced.matches?0:document.querySelector('#slow').checked?2.7:1;const time=s.variant.ms*factor;
 const animate=(el,frames,options)=>{const a=el.animate(frames,options);s.animations.push(a);return a.finished.catch(()=>{})};
 const arts=s.cards.map(el=>el.querySelector('.art'));
 const before=arts.map(el=>({rect:el.getBoundingClientRect(),radius:getComputedStyle(el).borderRadius}));
 const oldHeight=s.stage.offsetHeight;
 const copy=[...s.stage.querySelectorAll('.card-title,.card-meta,.watched,.cinema-copy'),...(s.extras?[s.extras]:[])].filter(el=>!el.hidden);
 // Clear the old labels first so they cannot jump or stretch with the artwork.
 await Promise.all(copy.map(el=>animate(el,[{opacity:1},{opacity:0}],{duration:75*factor,easing:'ease-out',fill:'forwards'})));
 change();layout(s);
 const finalHeight=s.stage.offsetHeight;
 s.stage.style.height=`${Math.max(oldHeight,finalHeight)}px`;
 const after=arts.map(el=>({rect:el.getBoundingClientRect(),radius:getComputedStyle(el).borderRadius}));
 const jobs=arts.map((el,i)=>{
   const a=before[i],b=after[i],rank=(i-s.selected+s.cards.length)%s.cards.length;
   const delay=(s.variant.id==='cascade'?rank*48:s.variant.id==='stack'?rank*15:rank*10)*factor;
   s.cards[i].style.zIndex=i===s.selected?6:2;
   const origin=s.stage.getBoundingClientRect();
   const box=v=>({left:v.rect.left-origin.left,top:v.rect.top-origin.top,width:v.rect.width,height:v.rect.height,radius:parseFloat(v.radius)});
   const keyframes=frames(s.variant.id,box(a),box(b),{index:i,focus:s.selected,viewport:s.stage.clientWidth});
   return animate(el,keyframes,{duration:time,delay,easing:'linear',fill:'both'});
 });
 if(s.variant.id==='cascade')jobs.push(animate(s.stage,[{filter:'blur(0px) brightness(1)'},{filter:'blur(3px) brightness(1.14)',offset:.43},{filter:'blur(0px) brightness(1)'}],{duration:time+240*factor,easing:'ease-in-out',fill:'both'}));
 const newCopy=[...s.stage.querySelectorAll('.card-title,.card-meta,.watched,.cinema-copy'),...(s.extras&&!s.extras.hidden?[s.extras]:[])].filter(el=>!el.hidden);
 // Let the eye follow the posters before revealing their new information.
 newCopy.forEach(el=>jobs.push(animate(el,[{opacity:0,transform:'translateY(7px)'},{opacity:1,transform:'translateY(0)'}],{duration:230*factor,delay:(s.variant.id==='stack'?660:s.variant.id==='cascade'?560:330)*factor,easing,fill:'both'})));
 try{await Promise.all(jobs)}finally{
   s.animations.forEach(a=>a.cancel());s.animations=[];
   s.stage.style.height=`${finalHeight}px`;
   s.cards.forEach((el,i)=>el.style.zIndex=i===s.selected?2:1);
   s.busy=false;s.phone.classList.remove('busy');
   if(s.pendingCompact!==undefined){const next=s.pendingCompact;delete s.pendingCompact;setLayout(s,next)}
 }
}
function setLayout(s,compact){if(s.busy){s.pendingCompact=compact;return}if(s.compact===compact)return;morph(s,()=>{s.compact=compact;storage.set(`nitrate-series-variant-${s.variant.id}`,compact?'compact':'large')});}
function rotate(s,delta){morph(s,()=>s.selected=(s.selected+delta+s.cards.length)%s.cards.length)}
function mark(s,i){if(s.seen.has(i)){s.seen.delete(i);toast(s,'Visionnage annulé dans cet aperçu.')}else{s.seen.add(i);toast(s,s.type==='series'?'Épisode marqué vu dans cet aperçu.':'Film marqué vu dans cet aperçu.')}const b=s.detail.querySelector('.detail-watch');if(b)b.innerHTML=icon(s.seen.has(i)?'undo-2':'check')+(s.seen.has(i)?'Annuler le visionnage':'Marquer comme vu');lucide.createIcons();}
function toast(s,message){clearTimeout(s.timer);const t=s.phone.querySelector('.toast');t.textContent=message;t.hidden=false;s.timer=setTimeout(()=>t.hidden=true,3500)}
function relativeRect(s,el){const r=el.getBoundingClientRect(),p=s.phone.getBoundingClientRect();return{left:r.left-p.left-1,top:r.top-p.top-1,width:r.width,height:r.height}}
async function fly(s,from,to,i,reverse=false){const el=document.createElement('div');el.className='flight';el.style.setProperty('--position',`${i%3*50}%`);Object.assign(el.style,{left:`${from.left}px`,top:`${from.top}px`,width:`${from.width}px`,height:`${from.height}px`,borderRadius:reverse?'0':'18px',...posterFrame(from.width,from.height,i)});s.phone.append(el);const animation=el.animate([{left:`${from.left}px`,top:`${from.top}px`,width:`${from.width}px`,height:`${from.height}px`,borderRadius:reverse?'0':'18px',...posterFrame(from.width,from.height,i)},{left:`${to.left}px`,top:`${to.top}px`,width:`${to.width}px`,height:`${to.height}px`,borderRadius:reverse?'18px':'0',...posterFrame(to.width,to.height,i)}],{duration:duration(),easing,fill:'forwards'});await animation.finished.catch(()=>{});el.remove();}
async function openDetail(s,i){if(s.busy)return;s.busy=true;s.opened=i;s.trigger=s.cards[i].querySelector('.art');const from=relativeRect(s,s.trigger),[title,meta,subtitle]=s.data[i];s.detail.innerHTML=`<div class="detail-art" style="--position:${i%3*50}%"></div><button class="detail-back" aria-label="Revenir à ${s.type==='series'?'mes séries':'mes films'}">${icon('arrow-left')}</button><div class="detail-body"><span class="eyebrow">${s.type==='series'?'PROCHAIN ÉPISODE':'DANS TA COLLECTION'}</span><h3>${title}</h3><div class="detail-meta">${meta} · ${subtitle}</div><button class="detail-watch">${icon(s.seen.has(i)?'undo-2':'check')}${s.seen.has(i)?'Annuler le visionnage':'Marquer comme vu'}</button><h4>${s.type==='series'?'Cet épisode':'Le film'}</h4><p>Un départ inattendu, une rencontre et la promesse d’un nouveau chapitre. Les personnages cherchent leur place alors que tout semble sur le point de changer.</p><p>Contenu de démonstration pour tester la transition.</p></div>`;s.detail.hidden=false;s.detail.scrollTop=0;s.detail.setAttribute('aria-label',title);s.library.inert=true;lucide.createIcons();const dest=s.detail.querySelector('.detail-art'),to=relativeRect(s,dest);Object.assign(dest.style,posterFrame(to.width,to.height,i));dest.style.visibility='hidden';const body=s.detail.querySelector('.detail-body');body.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:duration(),easing});s.detail.querySelector('.detail-back').onclick=()=>closeDetail(s);s.detail.querySelector('.detail-watch').onclick=()=>mark(s,i);await fly(s,from,to,i);dest.style.visibility='';s.busy=false;s.detail.querySelector('.detail-back').focus({preventScroll:true});}
async function closeDetail(s){if(s.busy||s.detail.hidden)return;s.busy=true;const art=s.detail.querySelector('.detail-art'),from=relativeRect(s,art);s.detail.hidden=true;s.library.inert=false;const to=relativeRect(s,s.trigger);s.trigger.style.visibility='hidden';await fly(s,from,to,s.opened,true);s.trigger.style.visibility='';s.busy=false;s.trigger.focus({preventScroll:true});}
const variants=[
{id:'arc',name:'01 · Trajectoire souple',subtitle:'Un mouvement continu, légèrement courbe',description:'La grande affiche mène le mouvement. Les autres la rejoignent en courbe, avec un ressort discret à l’arrivée.',source:'Motion · Arc',url:'https://motion.dev/docs/arc',steps:'COURBE → RESSORT DISCRET → STABILITÉ',ms:640},
{id:'cascade',name:'02 · Cascade ciné',subtitle:'Une vague de mouvement et de netteté',description:'Les affiches se réorganisent en cascade. Un flou très bref accompagne le déplacement, puis les images redeviennent nettes.',source:'Codrops · Grid Layout Transitions',url:'https://tympanus.net/Tutorials/GridLayoutTransitions/index2.html',steps:'DÉCALAGE → FLOU BREF → MISE AU POINT',ms:780},
{id:'stack',name:'03 · Passage en pile',subtitle:'La collection se rassemble, puis s’ouvre',description:'Les affiches forment un court instant une pile au centre, puis se distribuent dans la grille. La proposition la plus expressive.',source:'Codrops · Stack to Content',url:'https://tympanus.net/Development/ContentLayoutTransition/',steps:'RASSEMBLEMENT → PILE → DÉPLOIEMENT',ms:980}
];variants.forEach(v=>build('series',series,v));lucide.createIcons();document.querySelector('#replay').onclick=()=>{const compact=!states.every(s=>s.compact);states.forEach(s=>setLayout(s,compact))};let resizeTimer;window.addEventListener('resize',()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(()=>states.forEach(s=>{s.animations.forEach(a=>a.finish());layout(s)}),100)});

document.querySelector('#reset').onclick=()=>states.forEach(s=>setLayout(s,false));
