/* Original Nitrate vector study. All artwork and motion authored for this preview. */
(() => {
  const root = document.querySelector('main');
  const duration = 1600;
  function illustration(id) {
    return `<svg class="drawing" viewBox="0 0 200 176" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="rim-${id}" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#f1dece"/><stop offset=".52" stop-color="#b9a1d2"/><stop offset="1" stop-color="#8278aa"/></linearGradient>
        <linearGradient id="frame-${id}" x1="0" y1="0" x2=".5" y2="1"><stop stop-color="#686185"/><stop offset="1" stop-color="#2e304d"/></linearGradient>
        <linearGradient id="sky-${id}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#a49ccf"/><stop offset="1" stop-color="#596791"/></linearGradient>
        <radialGradient id="iris-${id}" cx=".35" cy=".25" r=".9"><stop stop-color="#ffd7b4"/><stop offset="1" stop-color="#be817e"/></radialGradient>
        <clipPath id="eye-${id}"><path class="eye-shape"/></clipPath>
      </defs>
      <g class="film" transform="translate(100 88) rotate(-7) translate(-100 -88)">
        <rect x="22" y="37" width="159" height="113" rx="20" fill="#090a12" opacity=".25"/>
        <rect x="20" y="28" width="160" height="116" rx="18" fill="url(#rim-${id})"/>
        <rect x="22" y="30" width="156" height="111" rx="16" fill="url(#frame-${id})"/>
        <rect x="39" y="37" width="122" height="96" rx="10" fill="#20263c" stroke="#a49abe" stroke-opacity=".42"/>
        <path d="M40 48 Q40 38 51 38 H148" fill="none" stroke="#e9dbe9" stroke-opacity=".25" stroke-linecap="round"/>
        ${[44,65,86,107,128].map(y => `<rect x="27" y="${y-4}" width="7" height="10" rx="2" fill="#191e33"/><rect x="166" y="${y-4}" width="7" height="10" rx="2" fill="#191e33"/>`).join('')}
        <path class="eye-outline eye-shape" fill="#eee0e6"/>
        <g clip-path="url(#eye-${id})">
          <rect x="49" y="57" width="102" height="58" fill="url(#sky-${id})"/>
          <g class="landscape"><path d="M43 110 L71 81 L85 91 L113 65 L157 111 V126 H43Z" fill="#5b628c"/><path d="M47 115 L81 91 L100 111 L130 83 L162 113 V126 H47Z" fill="#39486c"/><path d="M39 122 Q80 104 108 116 T163 111 V130 H39Z" fill="#263753"/></g>
          <g class="iris"><circle cx="100" cy="85" r="20" fill="url(#iris-${id})"/><circle cx="100" cy="85" r="11" fill="#27283e"/><circle cx="95" cy="80" r="3.4" fill="#f9eadc"/></g>
        </g>
        <path class="eye-border eye-shape" fill="none" stroke="#efdfec" stroke-width="2.4" stroke-linejoin="round"/>
        <path d="M81 122 H119" stroke="#b6a6cc" stroke-width="2" stroke-linecap="round" opacity=".55"/>
      </g></svg>`;
  }
  function refinedIllustration(id) {
    return `<svg class="drawing refined" viewBox="0 0 200 176" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="rim-${id}" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#f0e1e1"/><stop offset=".4" stop-color="#c5b4de"/><stop offset="1" stop-color="#777598"/></linearGradient>
        <linearGradient id="frame-${id}" x1="0" y1="0" x2=".3" y2="1"><stop stop-color="#736987"/><stop offset=".35" stop-color="#4b4865"/><stop offset="1" stop-color="#30364f"/></linearGradient>
        <linearGradient id="screen-${id}" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#1a2338"/><stop offset="1" stop-color="#2e3450"/></linearGradient>
        <linearGradient id="sky-${id}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#a6a2cb"/><stop offset=".64" stop-color="#858eb7"/><stop offset="1" stop-color="#bac1d2"/></linearGradient>
        <linearGradient id="lake-${id}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#a0b3cc"/><stop offset="1" stop-color="#4c627f"/></linearGradient>
        <radialGradient id="iris-${id}" cx=".32" cy=".25" r=".8"><stop stop-color="#f4d9ba"/><stop offset=".65" stop-color="#d3a499"/><stop offset="1" stop-color="#b98285"/></radialGradient>
        <clipPath id="eye-${id}"><path class="eye-shape"/></clipPath>
      </defs>
      <g class="film" transform="translate(100 88) rotate(-7) translate(-100 -88)">
        <rect x="22" y="33" width="157" height="115" rx="18" fill="#060b16" opacity=".23"/>
        <rect x="20" y="28" width="160" height="116" rx="18" fill="url(#rim-${id})"/>
        <rect x="21.8" y="29.7" width="156.4" height="111.4" rx="16.3" fill="url(#frame-${id})"/>
        <path d="M22.5 47 V45 Q22.5 30.5 38 30.5 H160 Q173 30.5 176 41" fill="none" stroke="#fff4ee" stroke-opacity=".23" stroke-width=".8" stroke-linecap="round"/>
        <path d="M27 133 Q31 140 40 140 H160 Q174 140 177 127" fill="none" stroke="#141b32" stroke-opacity=".48" stroke-width="1.5"/>
        <rect x="38.5" y="36.5" width="123" height="96.5" rx="11" fill="#11182b"/>
        <rect x="39.5" y="38" width="121" height="94" rx="10" fill="url(#screen-${id})" stroke="#b3a1c4" stroke-opacity=".3" stroke-width=".9"/>
        <path d="M41 51 V49 Q41 40 51 40 H148" fill="none" stroke="#eee3f1" stroke-opacity=".11" stroke-linecap="round"/>
        ${[44,65,86,107,128].map(y => `<g><rect x="27" y="${y-4}" width="7" height="10" rx="2.2" fill="#181f32"/><path d="M28 ${y+6} H33" stroke="#b6a5c8" stroke-opacity=".45" stroke-width=".7" stroke-linecap="round"/><rect x="166" y="${y-4}" width="7" height="10" rx="2.2" fill="#181f32"/><path d="M167 ${y+6} H172" stroke="#b6a5c8" stroke-opacity=".45" stroke-width=".7" stroke-linecap="round"/></g>`).join('')}
        <g clip-path="url(#eye-${id})">
          <rect x="47" y="54" width="106" height="62" fill="url(#sky-${id})"/>
          <g class="landscape">
            <path d="M45 103 L62 83 L68 88 L82 76 L100 101 L121 67 L138 87 L146 81 L164 106 V116 H45Z" fill="#737fa4"/>
            <path d="M106 92 L121 67 L117 83 L126 88 L122 88 L132 99Z" fill="#535f87"/>
            <path d="M42 110 L63 93 L74 98 L86 90 L101 110 L134 82 L145 97 L166 110 V120 H42Z" fill="#445d7e"/>
            <path d="M112 104 L134 82 L129 98 L140 104Z" fill="#354b6c"/>
            <path d="M48 107 Q75 100 95 106 T154 105 L152 123 H47Z" fill="url(#lake-${id})"/>
            <path d="M50 106 L67 104 L80 109 L67 112 L91 116 H45Z M155 105 L145 103 L130 109 L145 112 L126 118 H160Z" fill="#2c4561"/>
            <path d="M85 109 H113 M96 113 H122" fill="none" stroke="#d0d6e2" stroke-opacity=".5" stroke-width=".6" stroke-linecap="round"/>
          </g>
          <g class="iris"><circle cx="100" cy="84" r="18" fill="#283047" opacity=".12" transform="translate(0 1.5)"/><circle cx="100" cy="84" r="18" fill="url(#iris-${id})"/><circle cx="100" cy="84" r="16.8" fill="none" stroke="#f9dfc3" stroke-opacity=".35" stroke-width=".6"/><circle cx="100" cy="84" r="9.4" fill="#262b41"/><circle cx="100" cy="84" r="10.5" fill="none" stroke="#947d87" stroke-opacity=".4" stroke-width=".7"/><ellipse cx="96" cy="80" rx="2.7" ry="2.2" fill="#f9eadb"/><circle cx="103.5" cy="88" r="1" fill="#c9bfce" opacity=".65"/></g>
        </g>
        <path class="eye-border eye-shape" fill="none" stroke="#e8d9e8" stroke-width="2" stroke-linejoin="round"/>
        <path d="M84 122 H116" stroke="#b6a6cc" stroke-width="1.5" stroke-linecap="round" opacity=".55"/>
      </g></svg>`;
  }
  let variant = 'refined';
  root.querySelector('.hero-icon').innerHTML = refinedIllustration('large');
  root.querySelector('.collection').innerHTML = refinedIllustration('small');
  lucide.createIcons();
  let drawings = [...root.querySelectorAll('.drawing')];
  const timeline = root.querySelector('#timeline');
  const auto = root.querySelector('#auto');
  const status = root.querySelector('.status');
  const dialog = root.querySelector('dialog');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  let frame = 0, timer = 0, playing = false;
  const smooth = t => t*t*(3-2*t);
  function track(t, points) {
    for (let i=1; i<points.length; i++) {
      if (t <= points[i][0]) {
        const [a,x] = points[i-1], [b,y] = points[i];
        return x+(y-x)*smooth(Math.max(0,Math.min(1,(t-a)/(b-a))));
      }
    }
    return points.at(-1)[1];
  }
  function pose(ms) {
    const t = ms/duration;
    const refined = variant === 'refined';
    const open = track(t,refined ? [[0,1],[.18,1],[.26,0],[.29,0],[.47,1],[1,1]] : [[0,1],[.16,1],[.28,.025],[.35,.025],[.55,1],[1,1]]);
    const look = track(t,refined ? [[0,0],[.16,1.3],[.3,1.3],[.54,3],[.82,0],[1,0]] : [[0,0],[.16,2],[.35,2],[.58,5],[.8,-1],[1,0]]);
    const rotation = track(t,refined ? [[0,-7],[.2,-6],[.34,-7.8],[.58,-6.7],[.83,-7],[1,-7]] : [[0,-7],[.23,-5],[.43,-9],[.72,-6.5],[1,-7]]);
    const rise = track(t,refined ? [[0,0],[.21,-.8],[.34,.35],[.7,0],[1,0]] : [[0,0],[.28,-2],[.48,1],[1,0]]);
    const d = refined
      ? `M50 85 C72 ${89-35*open} 128 ${89-35*open} 150 85 C128 ${89+22*open} 72 ${89+22*open} 50 85Z`
      : `M50 85 C72 ${85-35*open} 128 ${85-35*open} 150 85 C128 ${85+35*open} 72 ${85+35*open} 50 85Z`;
    for (const svg of drawings) {
      svg.querySelectorAll('.eye-shape').forEach(p=>p.setAttribute('d',d));
      svg.querySelector('.iris').setAttribute('transform',`translate(${look} 0)`);
      svg.querySelector('.landscape').setAttribute('transform',`translate(${-look*.25} 0)`);
      svg.querySelector('.film').setAttribute('transform',`translate(100 ${88+rise}) rotate(${rotation}) translate(-100 -88)`);
    }
    timeline.value = ms;
    root.querySelector('#time').value = (ms/1000).toLocaleString('fr-FR',{minimumFractionDigits:2,maximumFractionDigits:2})+' s';
  }
  function stop(){cancelAnimationFrame(frame);playing=false;}
  function play(manual=false) {
    stop();
    if (reduced.matches) {pose(0);if(manual)status.textContent='Animations réduites : utilise la barre pour examiner les poses.';return;}
    playing=true;
    const started=performance.now();
    if(manual)status.textContent='Animation en cours.';
    function tick(now) {
      const ms=Math.min(duration,now-started);pose(ms);
      if(ms<duration)frame=requestAnimationFrame(tick);
      else {playing=false;if(manual)status.textContent='Animation terminée.';}
    }
    frame=requestAnimationFrame(tick);
  }
  function schedule(){clearInterval(timer);if(auto.checked&&!document.hidden&&!reduced.matches&&!dialog.open)timer=setInterval(()=>{if(!playing)play();},7000);}
  root.querySelector('#replay').onclick=root.querySelector('.hero-icon').onclick=()=>{play(true);schedule();};
  timeline.addEventListener('input',()=>{stop();clearInterval(timer);pose(Number(timeline.value));});
  timeline.addEventListener('change',schedule);
  auto.addEventListener('change',schedule);
  root.querySelectorAll('[data-version]').forEach(button => button.addEventListener('click',()=>{
    stop();
    variant=button.dataset.version;
    const draw=variant==='refined'?refinedIllustration:illustration;
    root.querySelector('.hero-icon').innerHTML=draw('large');
    root.querySelector('.collection').innerHTML=draw('small');
    drawings=[...root.querySelectorAll('.drawing')];
    root.querySelectorAll('[data-version]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
    pose(Number(timeline.value));
    status.textContent=variant==='refined'?'Version affinée.':'Version originale.';
    schedule();
  }));
  root.querySelector('.collection').onclick=()=>{stop();clearInterval(timer);dialog.showModal();status.textContent='Ouverture de Films vus.';};
  root.querySelector('#close').onclick=()=>dialog.close();
  dialog.addEventListener('close',schedule);
  document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();schedule();});
  function preference(){root.querySelector('#reduced').hidden=!reduced.matches;if(reduced.matches){stop();pose(0);}schedule();}
  reduced.addEventListener('change',preference);
  window.addEventListener('pagehide',()=>{stop();clearInterval(timer);});
  window.addEventListener('pageshow',schedule);
  pose(0);preference();play();
})();
