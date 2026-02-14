(list
  (channel
    (name 'guix)
    (url "https://git.guix.gnu.org/guix.git")
    (branch "master")
    (introduction
    (make-channel-introduction
      "9edb3f66fd807b096b48283debdcddccfea34bad"
    (openpgp-fingerprint
      "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
  (channel
    (name 'rde)
    (url "https://git.sr.ht/~abcdw/rde")
    (branch "master")
    (introduction
      (make-channel-introduction
        "257cebd587b66e4d865b3537a9a88cccd7107c95"
        (openpgp-fingerprint
          "2841 9AC6 5038 7440 C7E9  2FFA 2208 D209 58C1 DEB0"))))
  (channel
    (name 'selected-guix-works)
    (url "https://github.com/gs-101/selected-guix-works.git")
    (branch "main")
    (introduction
     (make-channel-introduction
      "5d1270d51c64457d61cd46ec96e5599176f315a4"
      (openpgp-fingerprint
       "C780 21F7 34E4 07EB 9090  0CF1 4ACA 6D6F 89AB 3162"))))
  (channel
    (name 'abbe)
    (url "https://codeberg.org/group/guix-modules.git")
    (branch "mainline")
    (introduction
      (make-channel-introduction
        "8c754e3a4b49af7459a8c99de130fa880e5ca86a"
        (openpgp-fingerprint
          "F682 CDCC 39DC 0FEA E116  20B6 C746 CFA9 E74F A4B0"))))
  (channel
    (name 'nonguix)
    (url "https://gitlab.com/nonguix/nonguix")
    (introduction
      (make-channel-introduction
        "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
        (openpgp-fingerprint
          "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5")))))