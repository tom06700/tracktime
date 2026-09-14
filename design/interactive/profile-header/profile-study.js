(() => {
  const $ = s => document.querySelector(s);
  const phone = $('#phone'), dialog = $('#editor'), avatar = $('#avatar'), target = $('#editor-avatar');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)');
  const emojis = ['🦸','🍿','🎬','👽','🦊','🐼','🦁','🐱','🐶','🚀'];
  let saved = {name:'Tom', emoji:'🦸'}, draft = {...saved}, busy = false, origin;
  const duration = () => reduce.matches ? 0 : ($('#slow').checked ? 1300 : 460);
  const curve = 'cubic-bezier(.22,.8,.25,1)';
  function sizeDialog() {
    const r = phone.getBoundingClientRect();
    dialog.style.left = r.left+'px'; dialog.style.top = Math.max(10,r.top)+'px';
    dialog.style.width = r.width+'px'; dialog.style.height = Math.min(r.height,innerHeight-Math.max(10,r.top)-12)+'px';
  }
  function fitName() {
    const name = $('#name'); name.style.fontSize = ''; name.style.letterSpacing = '';
    if (phone.classList.contains('before')) return;
    if(saved.name.length > 8){name.style.fontSize = saved.name.length > 15 ? '30px' : '40px';name.style.letterSpacing='-1px';}
  }
  function choices() {
    $('#emoji-grid').replaceChildren(...emojis.map(emoji => {
      const b = document.createElement('button'); b.type='button';b.textContent=emoji;b.setAttribute('aria-label','Avatar '+emoji);b.setAttribute('aria-pressed',String(emoji === draft.emoji));
      b.onclick=()=>{draft.emoji=emoji;target.querySelector('.emoji').textContent=emoji;choices();};return b;
    }));
  }
  async function fly(from,to,emoji) {
    if(!duration()) return;
    const host=dialog.getBoundingClientRect();
    const clone=document.createElement('div');clone.className='avatar flying-avatar';
    const child=document.createElement('span');child.className='emoji';child.textContent=emoji;clone.append(child);
    Object.assign(clone.style,{left:(to.left-host.left)+'px',top:(to.top-host.top+dialog.scrollTop)+'px',width:to.width+'px',height:to.height+'px',borderRadius:to.width/3+'px'});
    child.style.fontSize=to.width*.46+'px';dialog.append(clone);
    avatar.style.visibility='hidden';target.style.visibility='hidden';
    const a=clone.animate([{transform:`translate(${from.left-to.left}px,${from.top-to.top}px) scale(${from.width/to.width},${from.height/to.height})`},{transform:'translate(0,0) scale(1)'}],{duration:duration(),easing:curve});
    try{await a.finished;}catch{}finally{clone.remove();avatar.style.visibility='';target.style.visibility='';}
  }
  async function openEditor(button) {
    if(busy||dialog.open)return;busy=true;origin=button;
    draft={...saved};$('#input-name').value=draft.name;target.querySelector('.emoji').textContent=draft.emoji;choices();
    const from=avatar.getBoundingClientRect();sizeDialog();dialog.showModal();dialog.scrollTop=0;
    $('#cancel').focus({preventScroll:true});
    const to=target.getBoundingClientRect();
    if(duration()) {
      dialog.animate([{backgroundColor:'#10111300'},{backgroundColor:'#101113'}],{duration:duration(),easing:curve});
      [$('.editor-bar'),$('#input-name'),$('.field-label'),$('fieldset'),$('.editor-note')].forEach(el=>el.animate([{opacity:0,transform:'translateY(8px)'},{opacity:1,transform:'translateY(0)'}],{duration:duration()*.75,delay:duration()*.15,easing:curve,fill:'backwards'}));
    }
    await fly(from,to,draft.emoji);busy=false;
    $('#status').textContent='L’avatar accompagne l’ouverture de l’éditeur.';
  }
  async function closeEditor(save) {
    if(busy||!dialog.open)return;busy=true;
    if(save){saved={name:$('#input-name').value.trim()||'Cinéphile',emoji:draft.emoji};$('#name').textContent=saved.name;avatar.querySelector('.emoji').textContent=saved.emoji;fitName();}
    const from=target.getBoundingClientRect(),to=avatar.getBoundingClientRect();
    if(duration()) {
      $('.editor-content').animate([{opacity:1},{opacity:0}],{duration:duration()*.65,easing:curve,fill:'forwards'});
      $('.editor-bar').animate([{opacity:1},{opacity:0}],{duration:duration()*.65,easing:curve,fill:'forwards'});
    }
    await fly(from,to,save?saved.emoji:draft.emoji);
    dialog.close();dialog.querySelectorAll('*').forEach(el=>el.getAnimations().forEach(a=>a.cancel()));busy=false;origin?.focus({preventScroll:true});
    $('#status').textContent=save?'Profil mis à jour dans cet aperçu.':'Modifications annulées.';
  }
  $('#edit').onclick=e=>openEditor(e.currentTarget);avatar.onclick=e=>openEditor(e.currentTarget);
  $('#try-motion').onclick=e=>{setVersion(false);openEditor(e.currentTarget);};
  $('#cancel').onclick=()=>closeEditor(false);
  $('#edit-form').onsubmit=e=>{e.preventDefault();closeEditor(true);};
  dialog.addEventListener('cancel',e=>{e.preventDefault();closeEditor(false);});
  dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)closeEditor(false);}});
  function setVersion(before){phone.classList.toggle('before',before);$('#before').setAttribute('aria-pressed',String(before));$('#after').setAttribute('aria-pressed',String(!before));fitName();$('#status').textContent=before?'En-tête actuel, restitué depuis le code Flutter.':'Touche « Modifier » ou l’avatar.';}
  $('#before').onclick=()=>setVersion(true);$('#after').onclick=()=>setVersion(false);
  addEventListener('resize',()=>{if(dialog.open)sizeDialog();});
  reduce.addEventListener('change',()=>{if(reduce.matches)document.getAnimations().forEach(a=>a.finish());});
  lucide.createIcons();
})();
