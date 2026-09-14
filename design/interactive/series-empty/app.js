'use strict';
const concepts=[
{id:'fan',name:'L’éventail',title:'Ta prochaine série<br>commence ici.',body:'Choisis une histoire.<br>On garde le fil de tes épisodes.',cta:'Explorer les séries',description:'Les affiches se séparent, puis se posent. Un lien direct avec le bouton « Mes séries ».',recommended:true},
{id:'feature',name:'Le premier rôle',title:'Fais place à<br>ta prochaine obsession.',body:'Une série à découvrir.<br>Et bientôt, un épisode à retrouver.',cta:'Trouver ma première série',description:'Une affiche passe au premier plan. Glisse dessus ou touche les repères pour changer d’univers.'},
{id:'editorial',name:'La collection prend vie',title:'Une série suffit<br>pour commencer.',body:'Tes envies, tes épisodes, ton rythme.<br>Tout commence par une découverte.',cta:'Explorer les séries',description:'Le texte ouvre la page. Les affiches arrivent en cascade, puis restent à portée de glissement.'}
];
const catalogue=[{name:'Orbites',genre:'Science-fiction',art:0},{name:'Les Jours d’après',genre:'Drame',art:1},{name:'La Traversée',genre:'Aventure',art:2}];
const states=concepts.map(()=>({view:'series',saved:[],index:0}));
const reduce=matchMedia('(prefers-reduced-motion: reduce)');
const icon=name=>`<i data-lucide="${name}"></i>`;
const posters=()=>['a','b','c'].map(c=>`<div class="poster ${c}" aria-hidden="true"></div>`).join('');
const mini='<div class="mini-fan" aria-hidden="true"><span></span><span></span><span></span></div>';
const root=document.querySelector('#proposals');
root.innerHTML=concepts.map((c,i)=>`<article data-option="${i}"><div class="label"><span>0${i+1}</span><h2>${c.name}</h2>${c.recommended?'<span class="recommend">MA PRÉFÉRENCE</span>':''}</div><div class="viewport"><div class="screen"><div class="status"><span>9:41</span><span class="signals">${icon('signal')}${icon('wifi')}${icon('battery-full')}</span></div><div class="brand"><img src="assets/wordmark.svg" alt="Nitrate"><div class="brand-right"><button class="icon library" aria-label="Mes séries">${mini}</button><button class="icon bell" aria-label="Notifications">${icon('bell')}</button></div></div><div class="switch"><button class="active" data-mode="series">À voir</button><button data-mode="upcoming">À venir</button></div><div class="content"></div><nav class="nav" aria-label="Navigation de la proposition ${i+1}"><button class="selected" data-nav="series">${icon('tv-minimal')}Séries</button><button disabled title="Aperçu centré sur Séries">${icon('clapperboard')}Films</button><button data-nav="explore">${icon('compass')}Explorer</button><button disabled title="Aperçu centré sur Séries">${icon('user-round')}Profil</button></nav><div class="homebar"></div></div></div><p class="description">${c.description}</p><div class="option-tools"><button class="replay" aria-label="Rejouer la proposition ${i+1}">${icon('rotate-ccw')}Rejouer</button><button class="reset" aria-label="Réinitialiser la proposition ${i+1}">Repartir à zéro</button></div></article>`).join('');
const articles=[...root.children];
function icons(){lucide.createIcons();}
function emptyMarkup(c){
const copy=`<div class="copy"><h3>${c.title}</h3><p>${c.body}</p></div>`;
const art=c.id==='editorial'?`<div class="art-stage" aria-label="Illustrations à parcourir"><div class="ribbon" tabindex="0" aria-label="Trois univers illustrés, faire défiler horizontalement">${posters()}</div></div>`:`<div class="art-stage" role="button" tabindex="0" aria-label="${c.id==='fan'?'Animer les affiches':'Changer d’univers illustré'}">${posters()}${c.id==='fan'?`<span class="poster-mark">${icon('plus')}</span>`:`<div class="dots">${catalogue.map((_,i)=>`<button data-art="${i}" class="${i===0?'active':''}" aria-label="Univers illustré ${i+1}"></button>`).join('')}</div>`}</div>`;
return `<section class="empty ${c.id}">${c.id==='editorial'?copy+art:art+copy}<button class="primary explore-cta">${c.cta}${icon('arrow-up-right')}</button><span class="hint">${c.id==='feature'?'La suite se passe ici.':'Ta collection se construit à ton rythme.'}</span></section>`;
}
function cancel(i){articles[i].querySelectorAll('.poster').forEach(p=>p.getAnimations().forEach(a=>a.cancel()));}
function render(i,view='series'){
cancel(i);const a=articles[i],s=states[i],c=concepts[i];s.view=view;const content=a.querySelector('.content');
a.querySelectorAll('[data-nav]').forEach(b=>b.classList.toggle('selected',b.dataset.nav===(view==='explore'?'explore':'series')));
a.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('active',b.dataset.mode===view));a.querySelector('.switch').style.visibility=view==='explore'?'hidden':'visible';
if(view==='explore'){
content.innerHTML=`<section class="explore"><h3>Une envie de série ?</h3><label class="searchbox">${icon('search')}<input aria-label="Rechercher dans cet aperçu" placeholder="Rechercher une série" autocomplete="off"></label><p class="demo-note">Titres de démonstration</p><div class="results"></div></section>`;results(i,'');content.querySelector('input').addEventListener('input',e=>results(i,e.target.value));
}else if(view==='upcoming'){
content.innerHTML=`<section class="upcoming">${icon('calendar-days')}<h3>La suite arrive bientôt.</h3><p>Les prochains épisodes de tes séries<br>apparaîtront ici.</p><button class="primary explore-cta">Explorer les séries ${icon('arrow-up-right')}</button></section>`;
}else if(s.saved.length){const item=catalogue[s.saved[0]];
content.innerHTML=`<section class="collection"><div class="cover" style="background-position:${item.art*50}% 50%"></div><h3>${item.name}</h3><p>Saison 1 · Épisode 1</p><button class="primary explore-cta">Continuer à explorer ${icon('arrow-up-right')}</button></section>`;
}else{
content.innerHTML=emptyMarkup(c);const art=content.querySelector('.art-stage');
if(c.id==='fan'){art.onclick=()=>animate(i);art.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();animate(i);}};}
if(c.id==='feature'){
let dragged=false,start;art.onclick=e=>{if(!dragged&&!e.target.closest('[data-art]'))nextArt(i);dragged=false;};art.onkeydown=e=>{if(e.key==='Enter'||e.key==='ArrowRight'){e.preventDefault();nextArt(i);}if(e.key==='ArrowLeft'){e.preventDefault();nextArt(i,(s.index+2)%3);}};
art.onpointerdown=e=>{start=e.clientX;dragged=false;};art.onpointerup=e=>{if(Math.abs(e.clientX-start)>25){dragged=true;nextArt(i,(s.index+(e.clientX<start?1:2))%3);}};
art.querySelectorAll('[data-art]').forEach(b=>b.onclick=e=>{e.stopPropagation();nextArt(i,+b.dataset.art);});setArt(i);
}
if(c.id==='editorial'){
const rail=art.querySelector('.ribbon');let startX,left;
rail.onpointerdown=e=>{startX=e.clientX;left=rail.scrollLeft;rail.setPointerCapture(e.pointerId);rail.style.scrollSnapType='none';};rail.onpointermove=e=>{if(rail.hasPointerCapture(e.pointerId))rail.scrollLeft=left-(e.clientX-startX)/(parseFloat(a.querySelector('.screen').style.getPropertyValue('--scale'))||1);};rail.onpointerup=e=>{rail.releasePointerCapture(e.pointerId);rail.style.scrollSnapType='x mandatory';};
}requestAnimationFrame(()=>animate(i));
}
content.querySelectorAll('.explore-cta').forEach(b=>b.onclick=()=>render(i,'explore'));icons();
}
function results(i,q){const a=articles[i],s=states[i];const hits=catalogue.map((item,id)=>({...item,id})).filter(item=>item.name.toLocaleLowerCase().includes(q.toLocaleLowerCase()));
a.querySelector('.results').innerHTML=hits.map(item=>`<div class="result"><div class="cover" style="background-position:${item.art*50}% 50%"></div><button class="add ${s.saved.includes(item.id)?'added':''}" data-add="${item.id}" aria-label="${s.saved.includes(item.id)?'Retirer':'Ajouter'} ${item.name}">${icon(s.saved.includes(item.id)?'check':'plus')}</button><h4>${item.name}</h4><p>Série · ${item.genre}</p></div>`).join('')||'<p class="empty-result">Aucune série trouvée.</p>';
a.querySelectorAll('[data-add]').forEach(b=>b.onclick=()=>{const id=+b.dataset.add;const remove=s.saved.includes(id);s.saved=remove?s.saved.filter(x=>x!==id):[...s.saved,id];results(i,q);toast(i,remove?'Retiré de Mes séries':'Ajouté à Mes séries');});icons();}
function toast(i,text){const screen=articles[i].querySelector('.screen');screen.querySelector('.toast')?.remove();const t=document.createElement('div');t.className='toast';t.setAttribute('role','status');t.innerHTML=icon('check')+`<span>${text}</span>`;screen.append(t);icons();setTimeout(()=>t.remove(),2400);}
function timing(duration,delay=0){return {duration:reduce.matches?1:duration*(document.querySelector('#slow').checked?2.5:1),delay:reduce.matches?0:delay*(document.querySelector('#slow').checked?2.5:1),easing:'cubic-bezier(.22,1,.36,1)'};}
function setArt(i){const a=articles[i],index=states[i].index;a.querySelectorAll('.poster').forEach((p,n)=>p.className=`poster ${['a','b','c'][(index+n+1)%3]}`);a.querySelectorAll('[data-art]').forEach(b=>{b.classList.toggle('active',+b.dataset.art===index);b.setAttribute('aria-pressed',String(+b.dataset.art===index));});}
function nextArt(i,index=(states[i].index+1)%3){states[i].index=index;setArt(i);animate(i);}
function animate(i){const a=articles[i],c=concepts[i];if(states[i].view!=='series'||states[i].saved.length)return;cancel(i);a.querySelectorAll('.poster').forEach((p,n)=>{const final=getComputedStyle(p).transform;
if(c.id==='fan')p.animate([{transform:'translate(0px, 28px) rotate(0deg) scale(.93)',opacity:.75},{transform:final,opacity:1}],timing(1100,n===1?0:95));
else if(c.id==='feature')p.animate(n===2?[{transform:'translate(32px, 12px) rotateY(-16deg) rotate(6deg) scale(.92)',opacity:.4},{transform:final,opacity:1}]:[{transform:'translate(0,10px) scale(.86)',opacity:.65},{transform:final,opacity:1}],timing(1050,n*70));
else p.animate([{transform:'translate(35px, 46px) rotate(6deg)',opacity:0},{transform:'translate(0,0) rotate(0)',opacity:1}],timing(950,n*120));});}
articles.forEach((a,i)=>{a.querySelectorAll('[data-nav]').forEach(b=>b.onclick=()=>render(i,b.dataset.nav));a.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>render(i,b.dataset.mode));a.querySelector('.library').onclick=()=>render(i,'series');a.querySelector('.bell').onclick=()=>toast(i,'Aucune notification pour le moment.');a.querySelector('.replay').onclick=()=>{if(states[i].view!=='series'||states[i].saved.length){states[i].saved=[];render(i);}else animate(i);};a.querySelector('.reset').onclick=()=>{states[i].saved=[];states[i].index=0;render(i);};new ResizeObserver(([entry])=>a.querySelector('.screen').style.setProperty('--scale',entry.contentRect.width/390)).observe(a.querySelector('.viewport'));render(i);});
document.querySelector('#replay').onclick=()=>articles.forEach((_,i)=>{states[i].saved=[];render(i);});document.querySelector('#slow').onchange=()=>articles.forEach((_,i)=>animate(i));if(reduce.matches)document.querySelector('#auto').checked=false;document.querySelector('#auto').onchange=e=>{if(!e.target.checked)articles.forEach((_,i)=>cancel(i));};reduce.addEventListener('change',e=>{if(e.matches){document.querySelector('#auto').checked=false;articles.forEach((_,i)=>cancel(i));}});setInterval(()=>{if(document.hidden||reduce.matches||!document.querySelector('#auto').checked)return;articles.forEach((_,i)=>{if(concepts[i].id==='feature'&&states[i].view==='series'&&!states[i].saved.length)nextArt(i);else animate(i);});},7000);icons();

document.querySelector('#large').onchange=e=>document.body.classList.toggle('large',e.target.checked);
