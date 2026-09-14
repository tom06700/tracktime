import * as THREE from 'three';
import { passagePose } from './passage-motion.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
const clamp=THREE.MathUtils.clamp;
export function ease(a,b,t){let x=clamp((t-a)/(b-a),0,1);return x*x*x*(x*(x*6-15)+10);}
const mat=(color,metalness=.35,roughness=.28)=>new THREE.MeshPhysicalMaterial({color,metalness,roughness,clearcoat:.65,clearcoatRoughness:.22,envMapIntensity:1.5});
function mesh(geometry,material,parent,pos=[0,0,0]){const m=new THREE.Mesh(geometry,material);m.position.set(...pos);m.castShadow=true;m.receiveShadow=true;parent.add(m);return m;}
function arch(w,h,Path=THREE.Shape){const s=new Path(),r=w/2,y=h/2-r;s.moveTo(-r,-h/2);s.lineTo(r,-h/2);s.lineTo(r,y);s.absarc(0,y,r,0,Math.PI,false);s.lineTo(-r,-h/2);s.closePath();return s;}
function extrude(shape,depth=.15){return new THREE.ExtrudeGeometry(shape,{depth,bevelEnabled:true,bevelSegments:4,steps:1,bevelSize:.025,bevelThickness:.025,curveSegments:48});}
function groundShadow(scene){const c=document.createElement('canvas');c.width=c.height=128;const ctx=c.getContext('2d'),g=ctx.createRadialGradient(64,64,3,64,64,62);g.addColorStop(0,'rgba(0,0,0,.68)');g.addColorStop(.4,'rgba(0,0,0,.34)');g.addColorStop(1,'rgba(0,0,0,0)');ctx.fillStyle=g;ctx.fillRect(0,0,128,128);const tex=new THREE.CanvasTexture(c);const plane=mesh(new THREE.PlaneGeometry(4.4,3.6),new THREE.MeshBasicMaterial({map:tex,transparent:true,depthWrite:false}),scene,[0,-1.43,0]);plane.rotation.x=-Math.PI/2;return plane;}
export function createSculpture(element,type){
 const renderer=new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:'low-power'});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.setSize(390,337,false);renderer.setClearColor(0x101113,0);renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.15;element.append(renderer.domElement);
 const scene=new THREE.Scene();const pmrem=new THREE.PMREMGenerator(renderer),room=new RoomEnvironment();const env=pmrem.fromScene(room,.035);scene.environment=env.texture;scene.environmentIntensity=1.05;room.dispose();pmrem.dispose();
 const distance=Math.hypot(3,1.78,6.5), baseFov=2*Math.atan(1.83/distance)*180/Math.PI;
 const camera=type===0?new THREE.PerspectiveCamera(baseFov,390/337,.025,40):new THREE.OrthographicCamera(-2.12,2.12,1.83,-1.83,.1,30);
 camera.position.set(3,1.75,6.5);camera.lookAt(0,-.03,0);
 let entering=false,stageTop=0,startRotation=new THREE.Euler(),startPose=null;
 const aperture=arch(1.44,2.17).getPoints(48).map(p=>new THREE.Vector3(p.x,p.y,-.09));
 scene.add(new THREE.HemisphereLight(0xe9d9ff,0x37303d,1.3));const key=new THREE.DirectionalLight(0xfff5eb,3.2);key.position.set(-3,5,4);scene.add(key);const rim=new THREE.DirectionalLight(0xb396ff,2);rim.position.set(3,1,-3);scene.add(rim);
 const object=new THREE.Group();scene.add(object);groundShadow(scene);
 const build=[passage,orbit,ribbon][type];const animate=build(object,scene);
 let px=0,py=0,tx=0,ty=0,engagement=0,hovered=false,focused=false,inviteUntil=0,previousDraw=performance.now();
 const reduceMotion=matchMedia('(prefers-reduced-motion: reduce)');
 element.addEventListener('pointermove',e=>{const b=element.getBoundingClientRect();tx=(e.clientX-b.left)/b.width-.5;ty=(e.clientY-b.top)/b.height-.5;});
 element.addEventListener('pointerenter',e=>{if(type===0&&e.pointerType!=='touch')hovered=true;});
 element.addEventListener('pointerleave',()=>{tx=ty=0;hovered=false;});
 element.addEventListener('focus',()=>{if(type===0)focused=true;});
 element.addEventListener('blur',()=>focused=false);
 const target=()=>type===0&&(hovered||focused||performance.now()<inviteUntil)?1:0;
 return {
  invite(){if(type===0)inviteUntil=performance.now()+2100;},
  beginPortal(t,mode){
   if(type!==0||entering)return;
   stageTop=element.offsetTop; startPose=passagePose(t,mode,engagement);
   startRotation.copy(object.rotation);entering=true;
   renderer.setSize(390,844,false);
   element.classList.add('portal-stage');
  },
  portalFrame(seconds){
   const align=ease(0,.85,seconds),travel=ease(.27,1.88,seconds);
   const opening=ease(0,.72,seconds),reveal=ease(.25,.85,seconds);
   object.rotation.set(startRotation.x*(1-align),startRotation.y*(1-align),startRotation.z*(1-align));
   camera.fov=2*Math.atan(Math.tan(baseFov*Math.PI/360)*844/337)*180/Math.PI;
   camera.aspect=390/844;
   camera.position.set(3*(1-align),1.75*(1-align),6.5*(1-travel)+.055*travel);
   camera.lookAt(0,-.03*(1-align),0);camera.updateProjectionMatrix();
   camera.projectionMatrix.elements[9]=(2*(stageTop+168.5)/844-1)*(1-align);
   camera.projectionMatrixInverse.copy(camera.projectionMatrix).invert();
   animate(0,0,true,0,{...startPose,angle:THREE.MathUtils.lerp(startPose.angle,1.86,opening),light:startPose.light+opening*.35,spillOpacity:startPose.spillOpacity*(1-travel),interiorOpacity:1-reveal});
   scene.updateMatrixWorld(true);camera.updateMatrixWorld(true);
   const points=aperture.map(p=>{const v=p.clone().applyMatrix4(object.matrixWorld).project(camera);return `${((v.x+1)*195).toFixed(2)}px ${((1-v.y)*422).toFixed(2)}px`;});
   renderer.render(scene,camera);
   return {clip:`polygon(${points.join(',')})`,reveal,travel};
  },
  resetPortal(){
   if(type!==0)return;entering=false;startPose=null;
   renderer.setSize(390,337,false);element.classList.remove('portal-stage');
   camera.fov=baseFov;camera.aspect=390/337;camera.position.set(3,1.75,6.5);camera.lookAt(0,-.03,0);camera.updateProjectionMatrix();
   object.rotation.z=-.025;px=py=tx=ty=0;hovered=focused=false;inviteUntil=0;engagement=0;
  },
  needsRender(){return Math.abs(px-tx)+Math.abs(py-ty)>.001||Math.abs(engagement-target())>.001||inviteUntil>0;},
  draw(t,mode,still=false){
   if(entering)return;
   const now=performance.now(),dt=Math.min((now-previousDraw)/1000,.05);previousDraw=now;
   if(inviteUntil&&now>=inviteUntil)inviteUntil=0;
   const blend=reduceMotion.matches?1:1-Math.exp(-dt/.32);
   engagement+=(target()-engagement)*blend;
   px+=(tx-px)*.09;py+=(ty-py)*.09;object.rotation.y=px*.4;object.rotation.x=py*.16;
   animate(t,mode,still,engagement);renderer.render(scene,camera);
  },
  dispose(){env.dispose();renderer.dispose();scene.traverse(o=>{o.geometry?.dispose();if(o.material){(Array.isArray(o.material)?o.material:[o.material]).forEach(m=>m.dispose());}});}
 };

}
function passage(group,scene){
 group.rotation.z=-.025;
 const ceramic=mat(0xa88bda,.16,.38),dark=mat(0x5d487a,.4,.28),silver=mat(0xd8d4de,.94,.17);
 const outline=arch(1.86,2.58);outline.holes.push(arch(1.46,2.2,THREE.Path));mesh(extrude(outline,.29),ceramic,group,[0,0,-.12]);
 const interior=new THREE.ShaderMaterial({side:THREE.DoubleSide,transparent:true,depthWrite:false,uniforms:{opacity:{value:1},power:{value:0},mode:{value:0}},vertexShader:'varying vec2 vUv; void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'uniform float opacity; uniform float power; uniform float mode; varying vec2 vUv; void main(){ float y=clamp((vUv.y+1.1)/2.2,0.,1.); vec3 a=vec3(.26,.15,.43);vec3 b=mix(vec3(1.,.60,.39),vec3(.74,.67,1.),mode*.3); vec3 c=mix(b,a,y); c*=.75+power*.45;gl_FragColor=vec4(c,opacity); }'});
 mesh(new THREE.ShapeGeometry(arch(1.45,2.18),48),interior,group,[0,0,-.105]);
 const pivot=new THREE.Group();pivot.position.set(-.706,0,.23);group.add(pivot);mesh(extrude(arch(1.40,2.14),.105),dark,pivot,[.706,0,0]);
 // Fine raised inner surface catches the studio reflection when the door turns.
 mesh(extrude(arch(1.29,2.02),.006),ceramic,pivot,[.706,0,.118]);
 const handle=mesh(new THREE.CapsuleGeometry(.021,.21,5,12),silver,pivot,[1.24,-.24,.21]);
 for(const y of [-.70,.45])mesh(new THREE.CylinderGeometry(.036,.036,.22,16),silver,group,[-.744,y,.225]);
 const threshold=mesh(new THREE.BoxGeometry(1.52,.06,.48),silver,group,[0,-1.11,.10]);
 const spill=new THREE.Mesh(new THREE.PlaneGeometry(2.0,2.4),new THREE.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{alpha:{value:0}},vertexShader:'varying vec2 uvv;void main(){uvv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'varying vec2 uvv;uniform float alpha;void main(){float x=abs(uvv.x-.5);float v=(1.-smoothstep(.10,.49,x))*(1.-uvv.y)*smoothstep(0.,.18,uvv.y);gl_FragColor=vec4(1.,.55,.35,v*alpha);}' }));spill.rotation.x=-Math.PI/2;spill.position.set(0,-1.3,1.1);group.add(spill);
 return(t,mode,still,engagement=0,override=null)=>{
  const pose=override||passagePose(t,mode,engagement);
  interior.uniforms.opacity.value=pose.interiorOpacity??1;
  pivot.rotation.y=-pose.angle;
  interior.uniforms.power.value=pose.light;
  interior.uniforms.mode.value=mode;
  spill.material.uniforms.alpha.value=pose.spillOpacity;
  spill.scale.y=pose.spillLength;
 };

}
function orbit(group){
 const lilac=mat(0xbba2ec,.55,.21),silver=mat(0xd9d9e3,.92,.19),peach=mat(0xf3b392,.26,.23);
 const holder=new THREE.Group();holder.rotation.set(.4,-.22,-.36);group.add(holder);
 const rings=[];for(let i=0;i<3;i++){const ring=mesh(new THREE.TorusGeometry(.84+i*.16,.055+i*.014,16,100),i===1?silver:lilac,holder);rings.push(ring);}
 const core=mesh(new THREE.SphereGeometry(.29,40,24),peach,holder);
 const beads=[];for(let i=0;i<3;i++)beads.push(mesh(new THREE.SphereGeometry(i===0?.14:.10,28,18),i===1?peach:silver,holder));
 const pin=mesh(new THREE.SphereGeometry(.035,14,10),new THREE.MeshBasicMaterial({color:0xffe4d6}),holder,[0,.14,.26]);
 return(t,mode)=>{const spread=ease(.45,2.1,t)*(1-ease(4.5,6.45,t));const journey=ease(.65,4.3,t);holder.rotation.y=-.3+spread*.18;holder.position.y=.1+spread*.08;
 rings.forEach((r,i)=>{r.rotation.x=(i-1)*(.12+spread*1.02);r.rotation.y=(i-1)*spread*.4;r.rotation.z=i*.4+journey*Math.PI*2;});
 beads.forEach((b,i)=>{let a=(i/3)*Math.PI*2+journey*Math.PI*2;const radius=.84+i*.16;b.position.set(radius*Math.cos(a),radius*Math.sin(a),0);b.position.applyEuler(rings[i].rotation);b.scale.setScalar(mode===1?.6:1);});
 core.scale.setScalar((mode===2?1.2:1)+spread*.1);core.material.color.set(mode===2?0xd0d9b6:mode===1?0xc5aefd:0xf3b392);pin.visible=mode!==1;};
}
function ribbon(group){
 const segments=160,across=10,vertices=(segments+1)*(across+1);const positions=new Float32Array(vertices*3),indices=[];
 for(let i=0;i<segments;i++)for(let j=0;j<across;j++){const a=i*(across+1)+j,b=a+across+1;indices.push(a,b,a+1,b,b+1,a+1);}
 const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.BufferAttribute(positions,3));geometry.setIndex(indices);
 const satin=mat(0xaf92db,.65,.22);satin.side=THREE.FrontSide;const reverse=mat(0xe9bea9,.66,.24);reverse.side=THREE.BackSide;
 const strip=mesh(geometry,satin,group);mesh(geometry,reverse,group);group.position.y=.03;
 const tips=[mesh(new THREE.SphereGeometry(.05,20,14),mat(0xf0e2f6,.9,.16),group),mesh(new THREE.SphereGeometry(.05,20,14),mat(0xf0e2f6,.9,.16),group)];
 const tangent=new THREE.Vector3(),side=new THREE.Vector3(),center=new THREE.Vector3();
 return(t,mode)=>{const bloom=ease(.3,2.2,t)*(1-ease(4.4,6.5,t));const amplitude=.58+bloom*.42;const travel=ease(.5,4.6,t);const turn=Math.sin(travel*Math.PI*2)*.3;strip.rotation.y=0;group.rotation.z=-.22+turn*.13;
 for(let i=0;i<=segments;i++){const u=i/segments,a=(u-.5)*Math.PI*2;const wobble=Math.sin(a*2-t*.6)*bloom*.04;
 center.set(amplitude*Math.sin(a),a*(.35+bloom*.085),.39*Math.cos(a));tangent.set(amplitude*Math.cos(a),.35+bloom*.085,-.39*Math.sin(a)).normalize();
 const twist=u*Math.PI*1.7+turn+(mode===1?.5:0);side.set(Math.cos(twist),wobble,Math.sin(twist));side.addScaledVector(tangent,-side.dot(tangent)).normalize();
 for(let j=0;j<=across;j++){const v=j/across-.5,width=(mode===2?.47:.55)*(1-.12*Math.cos(a));const idx=(i*(across+1)+j)*3;positions[idx]=center.x+side.x*v*width;positions[idx+1]=center.y+side.y*v*width;positions[idx+2]=center.z+side.z*v*width+.035*Math.sin(j/across*Math.PI);}
 if(i===0)tips[0].position.copy(center);if(i===segments)tips[1].position.copy(center);
 }geometry.attributes.position.needsUpdate=true;geometry.computeVertexNormals();geometry.computeBoundingSphere();reverse.color.set(mode===2?0xc7d5ae:0xe9bea9);};
}
