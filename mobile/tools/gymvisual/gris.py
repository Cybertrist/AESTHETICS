# Personnage Gym visual, étape 1 (python gris.py) : corps gris (base_a dont le rouge est remplacé par base_b) et alignement des moitiés.
import numpy as np, cv2, json, glob, os
SRC=os.path.expanduser('~/.aesthetic/gymvisual')
TRAVAIL=os.path.join(SRC,'travail')  # intermédiaires, hors dépôt
def lire(f):
    im=cv2.imread(f,cv2.IMREAD_UNCHANGED)
    if im.shape[2]==3: im=np.dstack([im,np.full(im.shape[:2],255,np.uint8)])
    return im.astype(np.float32)  # BGRA
def rougeur(im): return im[...,2]-np.maximum(im[...,1],im[...,0])
def decale(ref,mov,x0,x1):
    # décalage horizontal entier de la moitié [x0,x1) qui superpose le mieux les alphas
    a=ref[:,x0:x1,3]/255; best=None
    for d in range(-45,46):
        xs0,xs1=max(0,x0+d),min(1080,x1+d)
        b=np.zeros_like(a); b[:,xs0-(x0+d):xs1-(x0+d)]=mov[:,xs0:xs1,3]/255
        s=-np.abs(a-b).sum()
        if best is None or s>best[0]: best=(s,d)
    return best[1]
def aligner(ref,mov):
    out=np.zeros_like(mov); ds=[]
    for x0,x1 in ((0,540),(540,1080)):
        d=decale(ref,mov,x0,x1); ds.append(d)
        M=np.float32([[1,0,-d],[0,1,0]])
        w=cv2.warpAffine(mov,M,(1080,1080),flags=cv2.INTER_NEAREST,borderValue=0)
        out[:,x0:x1]=w[:,x0:x1]
    return out,ds
if __name__=='__main__':
    os.makedirs(TRAVAIL,exist_ok=True)
    for g in ('male','female'):
        a=lire(f'{SRC}/{g}/base_a.png'); b,ds=aligner(a,lire(f'{SRC}/{g}/base_b.png'))
        ra=rougeur(a); rb=rougeur(b)
        w=np.clip((ra-2)/20,0,1); w=cv2.GaussianBlur(cv2.dilate(w,np.ones((5,5))),(0,0),0.8); w=np.maximum(w,np.clip((ra-2)/20,0,1))
        hors=(w<0.01)&(np.clip((rb-6)/30,0,1)<0.01)&(a[...,3]>250)&(b[...,3]>250)
        print(g,'décalages base_b',ds,'écart hors rouge',float(np.abs(a-b)[hors].mean()),float(np.abs(a-b)[hors].max()))
        gris=a*(1-w[...,None])+b*w[...,None]
        # gris strict : les trois canaux égaux (le rendu d'origine est déjà neutre)
        L=gris[...,:3].mean(2,keepdims=True)
        print(g,'écart à la neutralité',float(np.abs(gris[...,:3]-L)[gris[...,3]>0].max()),'rougeur max',float(rougeur(gris)[gris[...,3]>128].max()))
        gris[...,:3]=gris[...,:3]@np.array([0.114,0.587,0.299],np.float32)[:,None]
        cv2.imwrite(f'{TRAVAIL}/{g}_gris.png',np.clip(gris,0,255).astype(np.uint8))
