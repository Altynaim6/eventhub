import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {before, after, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc, deleteDoc, getDoc, Timestamp, serverTimestamp, runTransaction, writeBatch, collectionGroup, collection, query, where, getDocs} from 'firebase/firestore';
let env;
const data = () => ({title:'Событие', description:'Line one\nLine two', category:'Other',
  location:'Бишкек', capacity:10, organizerId:'owner', date:Timestamp.fromMillis(Date.now()+86400000)});
const ref = (uid='owner', id='event') => doc(uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore(),'events',id);
before(async () => {env=await initializeTestEnvironment({projectId:'demo-eventhub',firestore:{rules:readFileSync('../../firestore.rules','utf8')}});});
after(async () => {await env?.cleanup();});
beforeEach(async () => {
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c => {await setDoc(doc(c.firestore(),'events','event'),data());});
});
test('owner edits legacy event without createdAt and deletes',async()=>{
 await assertSucceeds(updateDoc(ref(),{title:'Обновлено',description:'Первая строка\nВторая строка'}));
 await assertSucceeds(deleteDoc(ref()));
});
test('foreign and anonymous writes denied',async()=>{
 for (const uid of ['other',null]) {
  await assertFails(updateDoc(ref(uid),{title:'Hijack'}));
  await assertFails(deleteDoc(ref(uid)));
 }
});
test('ownership, metadata and unknown fields immutable',async()=>{
 for (const change of [{organizerId:'other'},{createdAt:serverTimestamp()},{extra:true}]) {
  await assertFails(updateDoc(ref(),change));
 }
});
test('invalid content, date and capacity denied',async()=>{
 for (const change of [{title:'   '},{description:''},{location:''},{capacity:0},{capacity:1.5},{date:Timestamp.fromMillis(0)}]) {
  await assertFails(updateDoc(ref(),change));
 }
});
test('create validates owner and server timestamp',async()=>{
 await assertSucceeds(setDoc(ref('owner','new'),{...data(),createdAt:serverTimestamp()}));
 await assertFails(setDoc(ref('other','forged'),{...data(),createdAt:serverTimestamp()}));
 await assertFails(setDoc(ref('owner','invalid'),{...data(),capacity:-1,createdAt:serverTimestamp()}));
});
test('authenticated discovery and private profiles',async()=>{
 await assertSucceeds(getDoc(ref('other')));
 await assertFails(getDoc(ref(null)));
 const db=env.authenticatedContext('owner',{email:'owner@example.com'}).firestore();
 await assertSucceeds(setDoc(doc(db,'users','owner'),{name:'Owner',email:'owner@example.com',createdAt:serverTimestamp()}));
 await assertSucceeds(getDoc(doc(db,'users','owner')));
 await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'users','owner')));
 await assertFails(setDoc(doc(db,'users','other'),{name:'Forged'}));
 await assertFails(setDoc(doc(db,'events','event','registrations','owner'),{uid:'owner'}));
});

// Same two-document protocol as the Flutter repository, exercised against real rules.
async function change(uid, register = true, displayName) {
 const db = env.authenticatedContext(uid).firestore();
 const event = doc(db, 'events', 'event');
 const registration = doc(event, 'registrations', uid);
 return runTransaction(db, async tx => {
  const e = await tx.get(event);
  const r = await tx.get(registration);
  if (!e.exists()) throw Error('missing event');
  const count = e.data().registeredCount ?? 0;
  if (register) {
   if (r.exists()) throw Error('duplicate');
   if (count >= e.data().capacity) throw Error('full');
   tx.set(registration, {userId:uid, registeredAt:serverTimestamp(),
     ...(displayName === undefined ? {} : {displayName})});
  } else {
   if (!r.exists()) throw Error('not registered');
   tx.delete(registration);
  }
  tx.update(event, {registeredCount:count + (register ? 1 : -1)});
 });
}
const registration = uid => doc(ref(uid), 'registrations', uid);
test('registration and cancellation update count atomically; duplicate operations fail',async()=>{
 await change('alice');
 assert.equal((await getDoc(ref())).data().registeredCount,1);
 await assertSucceeds(getDoc(registration('alice')));
 await assert.rejects(change('alice'));
 await change('alice',false);
 assert.equal((await getDoc(ref())).data().registeredCount,0);
 assert.equal((await getDoc(registration('alice'))).exists(),false);
 await assert.rejects(change('alice',false));
 await change('alice');
});
test('simultaneous users compete for last place without overflow',async()=>{
 await updateDoc(ref(),{capacity:1});
 const results=await Promise.allSettled([change('alice'),change('bob')]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await getDoc(ref())).data().registeredCount,1);
 await env.withSecurityRulesDisabled(async c=>{
  const {getDocs,collection}=await import('firebase/firestore');
  assert.equal((await getDocs(collection(c.firestore(),'events/event/registrations'))).size,1);
 });
});
test('simultaneous duplicate requests reserve just one place',async()=>{
 const results=await Promise.allSettled([change('alice'),change('alice')]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await getDoc(ref())).data().registeredCount,1);
});
test('standalone count changes and registration writes rejected even for owner',async()=>{
 await assertFails(updateDoc(ref(),{registeredCount:1}));
 await assertFails(setDoc(registration('alice'),{userId:'alice',registeredAt:serverTimestamp()}));
 await change('alice');
 await assertFails(deleteDoc(registration('alice')));
 await assertFails(updateDoc(ref(),{registeredCount:0}));
 await assertFails(updateDoc(registration('alice'),{registeredAt:serverTimestamp()}));
});
test('malicious atomic writes cannot bypass capacity or modify other users',async()=>{
 await updateDoc(ref(),{capacity:1});
 await change('alice');
 const db=env.authenticatedContext('bob').firestore();
 const batch=writeBatch(db);
 batch.set(doc(db,'events/event/registrations/bob'),{userId:'bob',registeredAt:serverTimestamp()});
 batch.update(doc(db,'events/event'),{registeredCount:2});
 await assertFails(batch.commit());
 const attack=writeBatch(db);
 attack.delete(doc(db,'events/event/registrations/alice'));
 attack.update(doc(db,'events/event'),{registeredCount:0});
 await assertFails(attack.commit());
 await assertFails(getDoc(doc(db,'events/event/registrations/alice')));
});
test('capacity cannot fall below count and occupied event cannot be deleted',async()=>{
 await change('alice'); await change('bob');
 await assertFails(updateDoc(ref(),{capacity:1}));
 await assertFails(deleteDoc(ref()));
 await change('alice',false); await change('bob',false);
 await assertSucceeds(deleteDoc(ref()));
 await assert.rejects(change('alice'));
});
test('registration denied after start, cancellation still permitted',async()=>{
 await change('alice');
 await env.withSecurityRulesDisabled(async c=>{
  await updateDoc(doc(c.firestore(),'events/event'),{date:Timestamp.fromMillis(0)});
 });
 await assertFails(change('bob'));
 await assertSucceeds(change('alice',false));
});
test('forged registration metadata and multi-user batches rejected',async()=>{
 const db=env.authenticatedContext('alice').firestore();
 for (const payload of [{userId:'bob',registeredAt:serverTimestamp()},
   {userId:'alice',registeredAt:Timestamp.fromMillis(0)},
   {userId:'alice',registeredAt:serverTimestamp(),role:'organizer'}]) {
  const b=writeBatch(db);
  b.update(doc(db,'events/event'),{registeredCount:1});
  b.set(doc(db,'events/event/registrations/alice'),payload);
  await assertFails(b.commit());
 }
});
test('simultaneous cancellation requests release exactly one place',async()=>{
 await change('alice');
 const results=await Promise.allSettled([change('alice',false),change('alice',false)]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await getDoc(ref())).data().registeredCount,0);
});
test('capacity edit racing registration preserves capacity invariant',async()=>{
 await updateDoc(ref(),{capacity:2});
 await change('alice');
 const results=await Promise.allSettled([change('bob'),updateDoc(ref(),{capacity:1})]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const final=(await getDoc(ref())).data();
 assert.ok(final.registeredCount <= final.capacity);
});
test('atomic multi-user and anonymous registrations are rejected',async()=>{
 for (const uid of ['alice',null]) {
  const db=uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
  const batch=writeBatch(db);
  batch.update(doc(db,'events/event'),{registeredCount:2});
  for (const user of ['alice','bob']) {
   batch.set(doc(db,'events/event/registrations',user),{userId:user,registeredAt:serverTimestamp()});
  }
  await assertFails(batch.commit());
 }
 assert.equal((await getDoc(ref())).data().registeredCount,undefined);
});

test('my registrations group query is self-only and reflects cancellation',async()=>{
 await change('alice'); await change('bob');
 const db=env.authenticatedContext('alice').firestore();
 const own=query(collectionGroup(db,'registrations'),where('userId','==','alice'));
 const rows=await assertSucceeds(getDocs(own));
 assert.equal(rows.size,1);
 assert.equal(rows.docs[0].ref.path,'events/event/registrations/alice');
 await assertFails(getDocs(query(collectionGroup(db,'registrations'),where('userId','==','bob'))));
 await assertFails(getDocs(collectionGroup(db,'registrations')));
 await assertFails(getDocs(query(collectionGroup(env.unauthenticatedContext().firestore(),'registrations'),where('userId','==','alice'))));
 await change('alice',false);
 assert.equal((await getDocs(own)).size,0);
});

test('organizer lists participants with dates; other users cannot list roster',async()=>{
 await change('alice',true,'Alice'); await change('bob');
 const roster=await assertSucceeds(getDocs(collection(ref(),'registrations')));
 assert.equal(roster.size,2);
 const alice=roster.docs.find(d=>d.id==='alice').data();
 assert.equal(alice.displayName,'Alice'); assert.ok(alice.registeredAt instanceof Timestamp);
 for (const uid of ['alice','stranger',null]) {
  await assertFails(getDocs(collection(ref(uid),'registrations')));
 }
 await assertSucceeds(getDoc(registration('alice')));
 await change('alice',false);
 assert.equal((await getDocs(collection(ref(),'registrations'))).size,1);
 await assertFails(getDoc(doc(env.authenticatedContext('owner').firestore(),'users/alice')));
});
test('organizer cannot rewrite participant details or cancel someone else',async()=>{
 await change('alice');
 const db=env.authenticatedContext('owner').firestore();
 await assertFails(updateDoc(doc(db,'events/event/registrations/alice'),{displayName:'Forged'}));
 const batch=writeBatch(db);
 batch.delete(doc(db,'events/event/registrations/alice'));
 batch.update(doc(db,'events/event'),{registeredCount:0});
 await assertFails(batch.commit());
});
test('optional participant name validated; legacy registrations still supported',async()=>{
 for (const name of ['', '   ', 'x'.repeat(101), 42]) {
  await assertFails(change('alice',true,name));
 }
 await change('alice',true,'Participant');
 await change('bob');
 assert.equal((await getDoc(registration('bob'))).data().displayName,undefined);
});

test('profile name is self-editable; identity metadata and other profiles protected',async()=>{
 const db=env.authenticatedContext('alice',{email:'alice@example.com'}).firestore();
 const profile=doc(db,'users/alice');
 await assertSucceeds(setDoc(profile,{name:'Alice',email:'alice@example.com',createdAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(profile,{name:'Updated Alice'}));
 for (const payload of [{name:''},{name:'   '},{name:'x'.repeat(101)},
   {email:'forged@example.com'},{createdAt:serverTimestamp()},{role:'admin'}]) {
  await assertFails(updateDoc(profile,payload));
 }
 await assertFails(updateDoc(doc(env.authenticatedContext('bob').firestore(),'users/alice'),{name:'Hijack'}));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/alice')));
 await assertFails(getDocs(collection(db,'users')));
 await assertFails(deleteDoc(profile));
});
test('missing profile can be created by its user with trusted email and bounded name',async()=>{
 const db=env.authenticatedContext('alice',{email:'alice@example.com'}).firestore();
 const profile=doc(db,'users/alice');
 await assertFails(setDoc(profile,{name:'x'.repeat(101),email:'alice@example.com',createdAt:serverTimestamp()}));
 await assertFails(setDoc(profile,{name:'Alice',email:'bob@example.com',createdAt:serverTimestamp()}));
 await assertSucceeds(setDoc(profile,{name:'Alice',email:'alice@example.com',createdAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(profile,{name:String.fromCodePoint(0x1F642).repeat(100)}));
 await assertFails(updateDoc(profile,{name:String.fromCodePoint(0x1F642).repeat(101)}));
});
