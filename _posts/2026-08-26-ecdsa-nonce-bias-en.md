---
title: "ECDSA Nonce Bias"
date: 2026-08-26 10:53:00 +0700
lang: en
ref: ecdsa-nonce-bias
platform: knowledge
kn_cat: ecc
tags: [ecdsa, nonce, hnp, lattice]
description: When some nonce bits leak or are biased, the ECDSA private key can be recovered via the Hidden Number Problem and lattice reduction.
---

The ECDSA nonce `k` must stay fully secret and uniformly random. If part of `k`
leaks or is biased (say the MSBs are always zero, or a weak generator is used),
each signature leaks a little info about `k`. Collect enough of them and the
private key `D` falls via the **Hidden Number Problem (HNP)** solved with a
lattice.

## Starting point

The ECDSA signing equation for one message:

$$
s \equiv k^{-1}(z + rD) \pmod n
$$

where `z` is the (truncated) message hash, `r` is the x-coordinate of `kG`, `D`
is the private key, `n` is the group order. Rearrange for `k`:

$$
k \equiv s^{-1}z + s^{-1}rD \pmod n
$$

## HNP form

Suppose the nonce can be written `k = prefix + e`, where `prefix` is the known
part (published / predictable) and `e` is the small unknown part
($|e| < 2^\ell$, with $\ell$ = number of leaked bits, $\ell \ll \log_2 n$).

Substitute `k = prefix + e` into the equation above:

$$
\text{prefix} + e \equiv s^{-1}z + s^{-1}rD \pmod n
$$

Isolate the small unknown `e`:

$$
e \equiv s^{-1}rD + s^{-1}z - \text{prefix} \pmod n
$$

Cast it into the standard HNP shape $t\,D - u \equiv e \pmod n$:

$$
\underbrace{(s^{-1}r)}_{t}\,D \;-\; \underbrace{\left(\text{prefix} - s^{-1}z\right)}_{u} \;\equiv\; e \pmod n
$$

So for each signature `i`:

$$
t_i D - u_i \equiv e_i \pmod n, \qquad
t_i = r_i\,s_i^{-1}, \qquad
u_i = \text{prefix}_i - z_i\,s_i^{-1}
$$

<div class="callout danger"><span class="lbl">sign correction</span>
Mind the sign of <code>u_i</code>. The correct term is
<code>u_i = prefix_i - z_i·s_i^{-1}</code>, <b>not</b>
<code>z_i·s_i^{-1} - prefix_i</code>. Check: from <code>k = prefix + e</code> we
get <code>e = k - prefix</code>, and <code>k = s^{-1}z + s^{-1}rD</code>, hence
<code>e = tD + s^{-1}z - prefix = tD - (prefix - s^{-1}z)</code>. This only
matches when <code>u = prefix - s^{-1}z</code>.
</div>

## Verifying the derivation

Check `t·D - u = e` with `u = prefix - s⁻¹z`:

$$
tD - u = s^{-1}rD - \bigl(\text{prefix} - s^{-1}z\bigr)
       = s^{-1}rD + s^{-1}z - \text{prefix}
$$

Since `k = s⁻¹z + s⁻¹rD`, we have `s⁻¹rD + s⁻¹z = k`, therefore

$$
tD - u = k - \text{prefix} = e \quad\checkmark
$$

Consistent. Using the flipped sign (`u = s⁻¹z - prefix`) gives
`tD - u = k - prefix + 2·prefix - 2s⁻¹z`, which is clearly not `e`.

## From HNP to a lattice

Once you have many pairs $(t_i, u_i)$ with small $|e_i|$, look for the `D` that
makes every $t_iD - u_i \bmod n$ small. Build a lattice basis (classic
construction):

$$
B =
\begin{pmatrix}
n & 0 & \cdots & 0 & 0 \\
0 & n & \cdots & 0 & 0 \\
\vdots & & \ddots & & \vdots \\
t_1 & t_2 & \cdots & K/n & 0 \\
u_1 & u_2 & \cdots & 0 & K
\end{pmatrix}
$$

with `K` a scaling factor (around `2^ℓ`) to balance the weights. Reduce with
**LLL** (or BKZ if you need it stronger); the short vector that pops out contains
`D` (or the `e_i`), just read it back.

<div class="callout tip"><span class="lbl">practical note</span>
You need roughly <code>n / ℓ</code> signatures for the HNP to have a unique
solution. Fewer leaked bits per signature (small <code>ℓ</code>) means more
signatures needed. Even 1 bit of bias is enough given enough samples
(Bleichenbacher / FFT approach fits very small bias better).
</div>

## When it applies

- Nonce MSBs leak / are always zero (bad implementation, truncation).
- Nonce from a weak PRNG (LCG, time, partially guessable counter).
- Short nonce (e.g. 128-bit `k` on a 256-bit curve).

## Mitigation

- Deterministic nonce **RFC 6979**: `k = HMAC(d, z)`, fully uniform, no bias.
- Never truncate or reuse `k`.
- Modern schemes (Ed25519) use a built-in deterministic nonce, immune to this.

## References

- Howgrave-Graham & Smart, *Lattice Attacks on Digital Signature Schemes* (2001).
- Nguyen & Shparlinski, *The Insecurity of the DSA with Partially Known Nonces*.
