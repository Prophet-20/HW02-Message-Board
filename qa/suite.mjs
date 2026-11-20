import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, runTransaction, Timestamp} from 'firebase/firestore';
import {migrate} from './migrate.mjs';

const env = await initializeTestEnvironment({projectId:'demo-common-room', firestore:{
  host:'127.0.0.1',port:8180,rules:await readFile(new URL('../firestore.rules',import.meta.url),'utf8')}});
const alice=env.authenticatedContext('alice').firestore();
const bob=env.authenticatedContext('bob').firestore();
const guest=env.unauthenticatedContext().firestore();
const ref=(db)=>doc(db,'messages','one-intent');
const data=()=>({text:'Library at ten',authorUid:'alice',authorName:'Alice',schemaVersion:2,createdAt:serverTimestamp(),editedAt:null});
async function deny(label,operation){
  const error=await assertFails(operation);
  console.log('PASS',label,error.code);
}
try {
  await env.clearFirestore();
  await setDoc(doc(alice,'users/alice'),{uid:'alice',firstName:'Alice',lastName:'Park',role:'student',registrationDateTime:serverTimestamp()});
  await deny('private profile',getDoc(doc(bob,'users/alice')));
  await deny('signed-out read',getDoc(ref(guest)));
  await deny('forged author',setDoc(ref(bob),data()));
  async function createOnce(){await runTransaction(alice,async t=>{if(!(await t.get(ref(alice))).exists())t.set(ref(alice),data());});}
  await Promise.all([createOnce(),createOnce()]);
  const first=(await getDoc(ref(alice))).data();
  await createOnce();
  assert.deepEqual((await getDoc(ref(alice))).data(),first);
  await env.withSecurityRulesDisabled(async ctx=>{
    const {collection,getDocs}=await import('firebase/firestore');
    assert.equal((await getDocs(collection(ctx.firestore(),'messages'))).size,1);
  });
  console.log('PASS two concurrent sends + replay: one document, same creation timestamp');
  await assertSucceeds(getDoc(ref(bob)));
  await deny('cross-user edit',updateDoc(ref(bob),{text:'Other',editedAt:serverTimestamp()}));
  await deny('cross-user delete',deleteDoc(ref(bob)));
  await deny('owner transfer',updateDoc(ref(alice),{authorUid:'bob',editedAt:serverTimestamp()}));
  await updateDoc(ref(alice),{text:'Library at eleven',editedAt:serverTimestamp()});
  assert.equal((await getDoc(ref(bob))).data().text,'Library at eleven');
  await deleteDoc(ref(alice)); assert.equal((await getDoc(ref(bob))).exists(),false);
  console.log('PASS owner create, read, edit, delete; second user reads update and deletion');
  await env.withSecurityRulesDisabled(async ctx=>{
    const db=ctx.firestore(), sentAt=Timestamp.fromMillis(1800000000000);
    for (const [id,name] of [['a','Riley'],['b',null]]) {
      const legacy={uid:id,body:'Meet by the fountain '+id,sentAt,topic:'campus',...(name?{name}:{})};
      await setDoc(doc(db,'messages',id),legacy);
      console.log('BEFORE',id,JSON.stringify(legacy));
    }
    assert.equal(await migrate(db),2);
    for(const id of ['a','b']){
      const result=(await getDoc(doc(db,'messages',id))).data();
      assert.deepEqual(result,{authorUid:id,text:'Meet by the fountain '+id,createdAt:sentAt,topic:'campus',authorName:id==='a'?'Riley':'Member',editedAt:null,schemaVersion:2});
      console.log('AFTER',id,JSON.stringify(result));
    }
    assert.equal(await migrate(db),0);
    console.log('PASS migrated two legacy records; second run changed zero');
  });
} finally {await env.cleanup();}
