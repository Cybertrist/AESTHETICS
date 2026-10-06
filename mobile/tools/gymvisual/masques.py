# Étapes 2 à 4 (python masques.py ../../assets/body) : masques fins par muscle de l'API, regroupement vers l'enum, découpe face/dos, corps et buste.
import numpy as np, cv2, json, os, sys
from gris import lire, aligner, SRC, TRAVAIL
MARGE=12
CORPS=(424,1000)   # largeur, hauteur de la toile du corps entier (commune aux deux genres)
BUSTE=(424,424)
BUSTE_HAUT,BUSTE_BAS=0.12,0.52  # fraction de la hauteur de la figure (base du cou, hanches)
CORRESP={
 'pectoraux':['CHEST','PECTORALS','PECTORALIS MAJOR CLAVICULAR HEAD','PECTORALIS MAJOR STERNAL HEAD','UPPER CHEST'],
 'deltoidesAnterieurs':['ANTERIOR DELTOID'],
 'deltoidesLateraux':['LATERAL DELTOID'],
 'deltoidesPosterieurs':['POSTERIOR DELTOID','REAR DELTOIDS'],
 'biceps':['BICEPS','BICEPS BRACHII','BRACHIALIS'],
 'triceps':['TRICEPS','TRICEPS BRACHII'],
 'avantBras':['FOREARMS','BRACHIORADIALIS','WRIST EXTENSORS','WRIST FLEXORS','GRIP MUSCLES','WRISTS'],
 'trapezes':['TRAPEZIUS','TRAPS','TRAPEZIUS UPPER FIBERS','TRAPEZIUS MIDDLE FIBERS','TRAPEZIUS LOWER FIBERS'],
 'grandDorsal':['LATISSIMUS DORSI','LATS','TERES MAJOR'],
 'rhomboides':['RHOMBOIDS'],
 'lombaires':['ERECTOR SPINAE','LOWER BACK'],
 'abdominaux':['ABDOMINALS','ABS','RECTUS ABDOMINIS','TRANSVERSUS ABDOMINIS'],
 'obliques':['OBLIQUES','SERRATUS ANTERIOR','SERRATUS ANTE'],
 'fessiers':['GLUTES','GLUTEUS MAXIMUS'],
 'quadriceps':['QUADRICEPS','QUADS'],
 'ischios':['HAMSTRINGS'],
 'adducteurs':['ADDUCTORS','ADDUCTOR LONGUS','ADDUCTOR BREVIS','ADDUCTOR MAGNUS','INNER THIGHS','GROIN','PECTINEUS'],
 'abducteurs':['ABDUCTORS','GLUTEUS MEDIUS','GLUTEUS MINIMUS','TENSOR FASCIAE LATAE'],
 'mollets':['CALVES','GASTROCNEMIUS','SOLEUS'],
 'cou':['NECK','SPLENIUS','LEVATOR SCAPULAE'],
}
fichier=lambda m:''.join(c if c.isalnum() else '_' for c in m.lower())
def masque(gris,im):
    # part de vert et de bleu retirée par rapport au corps gris : 1 dans le rouge pur, quel que soit le relief
    gg=gris[...,1]+gris[...,0]; gm=im[...,1]+im[...,0]
    m=np.clip(1-gm/np.maximum(gg,8),0,1)
    m[(gris[...,3]<8)]=0
    m=np.where(m<0.12,0,m)                      # bruit de compression
    m=np.minimum(cv2.GaussianBlur(m,(0,0),0.7),cv2.dilate(m,np.ones((3,3))))  # bords adoucis sans baver
    return m*(gris[...,3]/255)
def cadre(gris):
    out={}
    for vue,(x0,x1) in (('face',(0,540)),('dos',(540,1080))):
        a=gris[:,x0:x1,3]>128; ys,xs=np.where(a)
        bx0,bx1,by0,by1=xs.min()+x0,xs.max()+x0+1,ys.min(),ys.max()+1
        cx=(bx0+bx1)/2
        W,H=CORPS; out[vue]=(int(round(cx-W/2)),int(round((by0+by1)/2-H/2)),W,H)
        h=by1-by0; t=by0+BUSTE_HAUT*h; b=by0+BUSTE_BAS*h
        W,H=BUSTE; out[vue+'_buste']=(int(round(cx-W/2)),int(round((t+b)/2-H/2)),W,H)
    return out
def couper(img,c):
    x,y,W,H=c; out=np.zeros((H,W)+img.shape[2:],img.dtype)
    sx0,sy0=max(0,x),max(0,y); sx1,sy1=min(img.shape[1],x+W),min(img.shape[0],y+H)
    out[sy0-y:sy1-y,sx0-x:sx1-x]=img[sy0:sy1,sx0:sx1]
    # la moitié voisine ne doit pas déborder dans la toile
    return out
def moitie(img,vue):
    o=img.copy()
    if vue.startswith('face'): o[:,540:]=0
    else: o[:,:540]=0
    return o
if __name__=='__main__':
    dest=sys.argv[1]
    noms=json.load(open(f'{SRC}/muscles.json'))
    for g,sous in (('male',''),('female','femme')):
        gris=cv2.imread(f'{TRAVAIL}/{g}_gris.png',cv2.IMREAD_UNCHANGED).astype(np.float32)
        C=cadre(gris); base=os.path.join(dest,sous); os.makedirs(f'{base}/masques',exist_ok=True); os.makedirs(f'{base}/masques/fins',exist_ok=True)
        fins={}; decal={}; S_=[]; H_=[]
        for n in noms:
            im,ds=aligner(gris,lire(f'{SRC}/{g}/muscles/{fichier(n)}.png')); decal[n]=ds
            fins[n]=masque(gris,im)
            # ombrage propre au rouge natif : rouge = couleur x s + h (h = reflet blanc)
            plein=fins[n]>0.9
            h=(im[...,1]+im[...,0])/2; s=(im[...,2]-h)/255
            S_.append(np.where(plein,s,np.nan).astype(np.float32)); H_.append(np.where(plein,h,np.nan).astype(np.float32))
        s=np.nanmedian(np.stack(S_),0); h=np.nanmedian(np.stack(H_),0); del S_,H_
        L=gris[...,1]; ok=np.isfinite(s)&(gris[...,3]>250)
        # hors des muscles de l'API (tête, mains, pieds) : s et h déduits du gris par médianes par tranche
        bins=np.arange(0,257,4); sb=[];hb=[]
        for b0 in bins[:-1]:
            k=ok&(L>=b0)&(L<b0+4)
            sb.append(np.median(s[k]) if k.sum()>20 else np.nan); hb.append(np.median(h[k]) if k.sum()>20 else np.nan)
        xs=bins[:-1]+2; sb=np.array(sb); hb=np.array(hb); v=np.isfinite(sb)
        s=np.where(np.isfinite(s),s,np.interp(L,xs[v],sb[v])); h=np.where(np.isfinite(h),h,np.interp(L,xs[v],hb[v]))
        teinte=np.dstack([np.zeros_like(h),np.clip(h,0,255),np.clip(s*255,0,255),gris[...,3]])  # BGRA : R = s, G = h
        manif={}
        for p,c in C.items():
            vue=p.split('_')[0]
            b=couper(moitie(gris,vue),c)
            cv2.imwrite(f'{base}/{p}_base.png',np.clip(b,0,255).astype(np.uint8))
            cv2.imwrite(f'{base}/{p}_teinte.png',np.clip(couper(moitie(teinte,vue),c),0,255).astype(np.uint8))
            presents=[]
            for mu,liste in CORRESP.items():
                u=np.zeros(gris.shape[:2],np.float32)
                for n in liste: u=np.maximum(u,fins[n])
                m=couper(moitie(u[...,None],vue),c)[...,0]
                if (m>0.5).sum()<60: continue
                presents.append(mu)
                cv2.imwrite(f'{base}/masques/{p}_{mu}.png',np.dstack([np.full(m.shape+(3,),255,np.uint8),(m*255).astype(np.uint8)]))
            manif[p]={'largeur':c[2],'hauteur':c[3],'masques':presents,'traits':False,'teinte':True}
            if '_' not in p:
                for n in noms:
                    m=couper(moitie(fins[n][...,None],vue),c)[...,0]
                    if (m>0.5).sum()<30: continue
                    cv2.imwrite(f'{base}/masques/fins/{p}_{fichier(n)}.png',(m*255).astype(np.uint8))
        manif['correspondance']={n:mu for mu,l in CORRESP.items() for n in l}
        manif['sansCorrespondance']=[n for n in noms if n not in manif['correspondance']]
        manif['source']='Gym visual, API Muscle Visualizer d\'ExerciseDB (1080 x 1080, rouge #FF0000)'
        json.dump(manif,open(f'{base}/masques/manifeste.json','w',encoding='utf-8'),ensure_ascii=False,indent=1)
        print(g,{p:len(v['masques']) for p,v in manif.items() if isinstance(v,dict) and 'masques' in v},'sans correspondance',manif['sansCorrespondance'])
        json.dump({'cadres':C,'decalages':decal},open(f'{TRAVAIL}/{g}_geo.json','w'),indent=1)
