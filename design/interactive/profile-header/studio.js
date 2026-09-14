(() => {
  const root=document.querySelector('.studio');
  const reduce=matchMedia('(prefers-reduced-motion:reduce)');
  const speed=document.querySelector('#speed');
  const status=document.querySelector('.motion-state');
  const dialog=document.querySelector('#identity-editor');
  let name='Tom', opener;
  const running=new Set();
  const curve='cubic-bezier(.22,.8,.26,1)';
  function motion(el,keyframes,duration,delay=0){
    if(!el||reduce.matches)return;
    const a=el.animate(keyframes,{duration:duration/Number(speed.value),delay:delay/Number(speed.value),easing:curve,fill:'backwards'});
    running.add(a);a.finished.catch(()=>{}).finally(()=>running.delete(a));
  }
  function cancel(section){section.querySelectorAll('*').forEach(el=>el.getAnimations().forEach(a=>a.cancel()));}
  function play(section){
    cancel(section);
    if(reduce.matches){status.textContent='Mouvements réduits';return;}
    const q=s=>section.querySelector(s);
    if(section.classList.contains('member')){
      motion(q('.hero'),[{opacity:0,transform:'perspective(800px) translateY(12px) rotateX(5deg)'},{opacity:1,transform:'perspective(800px) translateY(0) rotateX(0deg)'}],700);
      motion(q('.sweep'),[{opacity:0,transform:'translateX(-55%)'},{opacity:.8,offset:.4},{opacity:0,transform:'translateX(55%)'}],1200,120);
      motion(q('.avatar'),[{transform:'scale(.91)',opacity:0},{transform:'scale(1)',opacity:1}],650,100);
    }else if(section.classList.contains('spotlight')){
      motion(q('.spot-beam'),[{opacity:0,transform:'rotate(-9deg)'},{opacity:.95,transform:'rotate(0)'}],1150);
      motion(q('.portrait-stage'),[{opacity:0,transform:'translateY(10px) scale(.94)'},{opacity:1,transform:'translateY(0) scale(1)'}],850,140);
      motion(q('.eyebrow'),[{opacity:0,letterSpacing:'4px'},{opacity:1,letterSpacing:'2.8px'}],700,290);
      motion(q('.name'),[{opacity:0,transform:'translateY(8px)'},{opacity:1,transform:'translateY(0)'}],650,350);
      motion(q('.tagline'),[{opacity:0},{opacity:1}],600,430);
    }else{
      motion(q('.eyebrow'),[{opacity:0,transform:'translateX(-7px)'},{opacity:1,transform:'translateX(0)'}],550);
      motion(q('.name'),[{clipPath:'inset(100% 0 0 0)',transform:'translateY(14px)'},{clipPath:'inset(0 0 0 0)',transform:'translateY(0)'}],850,70);
      motion(q('.avatar'),[{opacity:0,transform:'translateY(8px) rotate(-3deg)'},{opacity:1,transform:'translateY(0) rotate(5deg)'}],850,130);
      motion(q('.tagline'),[{opacity:0,transform:'translateY(6px)'},{opacity:1,transform:'translateY(0)'}],650,230);
    }
    motion(q('.since'),[{opacity:0},{opacity:1}],550,350);
    status.textContent='Mouvement · '+section.dataset.label;
  }
  const sections=Array.from(root.querySelectorAll('.direction'));
  sections.forEach(section=>{
    section.querySelector('.replay').addEventListener('click',()=>play(section));
    const hero=section.querySelector('.hero');
    if(section.classList.contains('member')){
      hero.addEventListener('pointermove',e=>{
        if(reduce.matches||e.pointerType==='touch')return;
        const r=hero.getBoundingClientRect(),x=(e.clientX-r.left)/r.width,y=(e.clientY-r.top)/r.height;
        hero.style.transform=`perspective(850px) rotateX(${(0.5-y)*3}deg) rotateY(${(x-.5)*4}deg)`;
        hero.style.setProperty('--light-x',(x*100)+'%');hero.style.setProperty('--light-y',(y*100)+'%');
      });
      hero.addEventListener('pointerleave',()=>{hero.style.transform='';hero.style.removeProperty('--light-x');hero.style.removeProperty('--light-y');});
    }
  });
  document.querySelector('#replay-all').addEventListener('click',()=>sections.forEach(play));
  speed.addEventListener('input',()=>{document.querySelector('#speed-value').textContent=Number(speed.value).toLocaleString('fr-FR')+'×';});
  root.querySelectorAll('[data-edit]').forEach(button=>button.addEventListener('click',()=>{
    opener=button;document.querySelector('#profile-name').value=name;dialog.showModal();
    motion(dialog,[{opacity:0,transform:'translateY(16px) scale(.98)'},{opacity:1,transform:'translateY(0) scale(1)'}],280);
  }));
  dialog.querySelectorAll('[data-close]').forEach(b=>b.addEventListener('click',()=>dialog.close()));
  dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close();}});
  dialog.addEventListener('close',()=>opener?.focus({preventScroll:true}));
  dialog.querySelector('form').addEventListener('submit',e=>{
    e.preventDefault();name=document.querySelector('#profile-name').value.trim()||'Cinéphile';
    root.querySelectorAll('.name').forEach(n=>{n.textContent=name;n.style.fontSize=name.length>13?(n.closest('.editorial')?'42px':'29px'):'';});
    dialog.close();status.textContent='Prénom modifié dans les trois aperçus';
  });
  document.addEventListener('visibilitychange',()=>{if(document.hidden)running.forEach(a=>a.cancel());});
  reduce.addEventListener('change',()=>{if(reduce.matches){running.forEach(a=>a.cancel());status.textContent='Mouvements réduits';}});
  lucide.createIcons();
  document.fonts.ready.then(()=>sections.forEach(play));
})();
