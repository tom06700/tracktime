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
  root.querySelector('.hero-icon').innerHTML = illustration('large');
  root.querySelector('.collection').innerHTML = illustration('small');
  lucide.createIcons();
  const drawings = [...root.querySelectorAll('.drawing')];
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
    const open = track(t,[[0,1],[.16,1],[.28,.025],[.35,.025],[.55,1],[1,1]]);
    const look = track(t,[[0,0],[.16,2],[.35,2],[.58,5],[.8,-1],[1,0]]);
    const rotation = track(t,[[0,-7],[.23,-5],[.43,-9],[.72,-6.5],[1,-7]]);
    const rise = track(t,[[0,0],[.28,-2],[.48,1],[1,0]]);
    const d = `M50 85 C72 ${85-35*open} 128 ${85-35*open} 150 85 C128 ${85+35*open} 72 ${85+35*open} 50 85Z`;
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
