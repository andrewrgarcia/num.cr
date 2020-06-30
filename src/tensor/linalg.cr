# Copyright (c) 2020 Crystal Data Contributors
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require "./tensor"
require "./extension"
require "./work"

class Tensor(T)
  # Computes the upper triangle of a `Tensor`.  Zeros
  # out values below the `k`th diagonal
  #
  # Arguments
  # ---------
  # *k* : Int
  #   Diagonal
  #
  # Examples
  # --------
  # ```
  # a = Tensor(Int32).ones([3, 3])
  # a.triu!
  # a
  #
  # # [[1, 1, 1],
  # #  [0, 1, 1],
  # #  [0, 0, 1]]
  # ```
  def triu!(k : Int = 0)
    self.each_pointer_with_index do |e, i|
      m = i // @shape[1]
      n = i % @shape[1]
      e.value = m > n - k ? T.new(0) : e.value
    end
  end

  # :ditto:
  def triu(k : Int = 0)
    t = self.dup
    t.triu!(k)
    t
  end

  # Computes the lower triangle of a `Tensor`.  Zeros
  # out values above the `k`th diagonal
  #
  # Arguments
  # ---------
  # *k* : Int
  #   Diagonal
  #
  # Examples
  # --------
  # ```
  # a = Tensor(Int32).ones([3, 3])
  # a.tril!
  # a
  #
  # # [[1, 0, 0],
  # #  [1, 1, 0],
  # #  [1, 1, 1]]
  # ```
  def tril!(k : Int = 0)
    self.each_pointer_with_index do |e, i|
      m = i // @shape[1]
      n = i % @shape[1]
      e.value = m < n - k ? T.new(0) : e.value
    end
  end

  # :ditto:
  def tril(k : Int = 0)
    t = self.dup
    t.tril!(k)
    t
  end

  # Cholesky decomposition.
  #
  # Return the Cholesky decomposition, L * L.H, of the square matrix a, where
  # L is lower-triangular and .H is the conjugate transpose operator (which
  # is the ordinary transpose if a is real-valued). a must be Hermitian
  # (symmetric if real-valued) and positive-definite. Only L is actually
  # returned.
  #
  # Arguments
  # ---------
  # *lower*
  #   Triangular of decomposition to return
  #
  # Examples
  # --------
  # ```
  # t = [[2, -1, 0], [-1, 2, -1], [0, -1, 2]].to_tensor.astype(Float32)
  # t.cholesky
  #
  # # [[ 1.414,    0.0,    0.0],
  # #  [-0.707,  1.225,    0.0],
  # #  [   0.0, -0.816,  1.155]]
  # ```
  def cholesky!(*, lower = true)
    self.is_square_matrix
    self.is_fortran

    char = lower ? 'L' : 'U'
    lapack(potrf, char.ord.to_u8, shape[0], to_unsafe, shape[0])
    lower ? tril! : triu!
  end

  # :ditto:
  def cholesky(*, lower = true)
    t = self.dup(Num::ColMajor)
    t.cholesky!
    t
  end

  # Compute the qr factorization of a matrix.
  #
  # Factor the matrix a as qr, where q is orthonormal and r is
  # upper-triangular.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```crystal
  # t = [[0, 1], [1, 1], [1, 1], [2, 1]].to_tensor.as_type(Float32)
  # q, r = t.qr
  # puts q
  # puts r
  #
  # # [[   0.0,  0.866],
  # #  [-0.408,  0.289],
  # #  [-0.408,  0.289],
  # #  [-0.816, -0.289]]
  # # [[-2.449, -1.633],
  # #  [   0.0,  1.155],
  # #  [   0.0,    0.0],
  # #  [   0.0,    0.0]]
  # ```
  def qr
    self.is_matrix
    m, n = @shape
    k = {m, n}.min
    a = self.dup(Num::ColMajor)
    tau = Tensor(T).new([k])
    jpvt = Tensor(Int32).new([1])
    lapack(geqrf, m, n, a.to_unsafe, m, tau.to_unsafe)
    r = a.triu
    lapack(orgqr, m, n, k, a.to_unsafe, m, tau.to_unsafe)
    {a, r}
  end

  # Singular Value Decomposition.
  #
  # When a is a 2D array, it is factorized as u @ np.diag(s) @ vh = (u * s) @ vh,
  # where u and vh are 2D unitary arrays and s is a 1D array of a’s singular
  # values.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```crystal
  # t = [[0, 1], [1, 1], [1, 1], [2, 1]].to_tensor.as_type(Float32)
  # a, b, c = t.svd
  # puts a
  # puts b
  # puts c
  #
  # # [[-0.203749, 0.841716 , -0.330613, 0.375094 ],
  # #  [-0.464705, 0.184524 , -0.19985 , -0.842651],
  # #  [-0.464705, 0.184524 , 0.861075 , 0.092463 ],
  # #  [-0.725662, -0.472668, -0.330613, 0.375094 ]]
  # # [3.02045 , 0.936426]
  # # [[-0.788205, -0.615412],
  # #  [-0.615412, 0.788205 ]]
  # ```
  def svd
    self.is_matrix
    a = dup(Num::ColMajor)
    m, n = a.shape
    mn = {m, n}.min
    mx = {m, n}.max
    s = Tensor(T).new([mn])
    u = Tensor(T).new([m, m])
    vt = Tensor(T).new([n, n])
    lapack(gesdd, 'A'.ord.to_u8, m, n, a.to_unsafe, m, s.to_unsafe, u.to_unsafe, m,
      vt.to_unsafe, n, worksize: [{5*mn*mn + 5*mn, 2*mx*mn + 2*mn*mn + mn}.max, 8*mn])
    {u.transpose, s, vt.transpose}
  end

  # Compute the eigenvalues and right eigenvectors of a square `Tensor`.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```crystal
  # t = [[0, 1], [1, 1]].to_tensor.as_type(Float32)
  # w, v = t.eigh
  # puts w
  # puts v
  #
  # # [-0.618034, 1.61803  ]
  # # [[-0.850651, 0.525731 ],
  # #  [0.525731 , 0.850651 ]]
  # ```
  def eigh
    self.is_square_matrix
    a = dup(Num::ColMajor)
    n = a.shape[0]
    w = Tensor(T).new([n])
    lapack(
      syev,
      'V'.ord.to_u8,
      'L'.ord.to_u8,
      n,
      a.to_unsafe,
      n,
      w.to_unsafe,
      worksize: 3 * n - 1
    )
    {w, a}
  end

  # Compute the eigenvalues and right eigenvectors of a square array.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```crystal
  # t = [[0, 1], [1, 1]].to_tensor.as_type(Float32)
  # w, v = t.eig
  # puts w
  # puts v
  #
  # # [-0.618034, 1.61803  ]
  # # [[-0.850651, 0.525731 ],
  # #  [-0.525731, -0.850651]]
  # ```
  def eig
    self.is_square_matrix
    a = dup(Num::ColMajor)
    n = a.shape[0]
    wr = Tensor(T).new([n])
    wl = wr.dup
    vl = Tensor(T).new([n, n], Num::RowMajor)
    vr = wr.dup
    lapack(geev, 'V'.ord.to_u8, 'V'.ord.to_u8, n, a.to_unsafe, n, wr.to_unsafe,
      wl.to_unsafe, vl.to_unsafe, n, vr.to_unsafe, n, worksize: 3 * n)
    {wr, vl}
  end

  # Compute the eigenvalues of a general matrix.
  #
  # Main difference between eigvals and eig: the eigenvectors aren’t
  # returned.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```
  # t = [[0, 1], [1, 1]].to_tensor.as_type(Float32)
  # puts t.eigvalsh
  #
  # # [-0.618034, 1.61803  ]
  # ```
  def eigvalsh
    self.is_square_matrix
    a = dup(Num::ColMajor)
    n = a.shape[0]
    w = Tensor(T).new([n])
    lapack(syev, 'N'.ord.to_u8, 'L'.ord.to_u8, n, a.to_unsafe, n, w.to_unsafe, worksize: 3 * n - 1)
    w
  end

  # Compute the eigenvalues of a general matrix.
  #
  # Main difference between eigvals and eig: the eigenvectors aren’t
  # returned.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```
  # t = [[0, 1], [1, 1]].to_tensor.as_type(Float32)
  # puts t.eigvals
  #
  # # [-0.618034, 1.61803  ]
  # ```
  def eigvals
    self.is_square_matrix
    a = self.dup(Num::ColMajor)
    n = a.shape[0]
    wr = Tensor(T).new([n])
    wl = wr.dup
    vl = Tensor(T).new([n, n])
    vr = wr.dup
    lapack(geev, 'N'.ord.to_u8, 'N'.ord.to_u8, n, a.to_unsafe, n, wr.to_unsafe,
      wl.to_unsafe, vl.to_unsafe, n, vr.to_unsafe, n, worksize: 3 * n)
    wr
  end

  # Matrix norm
  #
  # This function is able to return one of eight different matrix norms
  #
  # Arguments
  # ---------
  # *order* : String
  #   Type of norm
  #
  # Examples
  # --------
  # ```crystal
  # t = [[0, 1], [1, 1], [1, 1], [2, 1]].to_tensor.as_type(Float32)
  # t.norm # => 3.6055512
  # ```
  def norm(*, order = 'F')
    self.is_matrix
    a = self.dup(Num::ColMajor)
    m, n = a.shape
    worksize = order == 'I' ? m : 0
    lapack_util(lange, worksize, order.ord.to_u8, m, n, tensor(a.to_unsafe), m)
  end

  # Compute the determinant of an array.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```crystal
  # t = [[1, 2], [3, 4]].to_tensor.astype(Float32)
  # puts t.det # => -2.0
  # ```
  def det
    self.is_square_matrix
    a = dup(Num::ColMajor)
    m, n = a.shape
    ipiv = Pointer(Int32).malloc(n)

    lapack(getrf, m, n, a.to_unsafe, n, ipiv)
    ldet = Num.prod(a.diagonal)
    detp = 1
    n.times do |j|
      if j + 1 != ipiv[j]
        detp = -detp
      end
    end
    ldet * detp
  end

  # Compute the (multiplicative) inverse of a matrix.
  #
  # Given a square matrix a, return the matrix ainv satisfying
  # dot(a, ainv) = dot(ainv, a) = eye(a.shape[0])
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```crystal
  # t = [[1, 2], [3, 4]].to_tensor.as_type(Float32)
  # puts t.inv
  #
  # # [[-2  , 1   ],
  # #  [1.5 , -0.5]]
  # ```
  def inv
    self.is_square_matrix
    a = dup(Num::ColMajor)
    n = a.shape[0]
    ipiv = Pointer(Int32).malloc(n)
    lapack(getrf, n, n, a.to_unsafe, n, ipiv)
    lapack(getri, n, a.to_unsafe, n, ipiv, worksize: n * n)
    a
  end

  # Solve a linear matrix equation, or system of linear scalar equations.
  #
  # Computes the “exact” solution, x, of the well-determined, i.e., full rank,
  # linear matrix equation ax = b.
  #
  # Arguments
  # ---------
  # *x* : Tensor
  #   Argument with which to solve
  #
  # Examples
  # --------
  # ```crystal
  # a = [[3, 1], [1, 2]].to_tensor.astype(Float32)
  # b = [9, 8].to_tensor.astype(Float32)
  # puts a.solve(b)
  #
  # # [2, 3]
  # ```
  def solve(x : Tensor(T))
    self.is_square_matrix
    a = dup(Num::ColMajor)
    x = x.dup(Num::ColMajor)
    n = a.shape[0]
    m = x.rank > 1 ? x.shape[1] : x.shape[0]
    ipiv = Pointer(Int32).malloc(n)
    lapack(gesv, n, m, a.to_unsafe, n, ipiv, x.to_unsafe, m)
    x
  end

  # Compute Hessenberg form of a matrix.
  #
  # The Hessenberg decomposition is:
  #
  # ```
  # A = Q H Q^H
  # ```
  #
  # where Q is unitary/orthogonal and H has only zero elements below the first sub-diagonal.
  #
  # Arguments
  # ---------
  #
  # Examples
  # --------
  # ```
  # a = [[2, 5, 8, 7],
  #      [5, 2, 2, 8],
  #      [7, 5, 6, 6],
  #      [5, 4, 4, 8]].to_tensor.as_type(Float64)
  #
  # puts a.hessenberg
  #
  # # [[2       , -11.6584, 1.42005 , 0.253491],
  # #  [-9.94987, 14.5354 , -5.31022, 2.43082 ],
  # #  [0       , -1.83299, 0.3897  , -0.51527],
  # #  [0       , 0       , -3.8319 , 1.07495 ]]
  # ```
  def hessenberg
    self.is_square_matrix
    a = dup(Num::ColMajor)

    if a.shape[0] < 2
      return a
    end

    n = a.shape[0]
    s = of_real_type(n)
    ilo = 0
    ihi = 0
    lapack(gebal, 'B'.ord.to_u8, n, a.to_unsafe, n, ilo, ihi, s.to_unsafe)
    tau = Tensor(T).new([n])
    lapack(gehrd, n, ilo, ihi, a.to_unsafe, n, tau.to_unsafe)
    a.triu(-1)
  end

  # Computes a matrix multiplication between two `Tensors`.  The `Tensor`s
  # must be two dimensional with compatible shapes.  Currently
  # only Float and Complex `Tensor`s are supported, as BLAS is used
  # for this operation
  #
  # Arguments
  # ---------
  # *other* : Tensor(T)
  #   The right hand side of the operation
  #
  # Examples
  # --------
  # ```
  # Num::Rand.set_seed(0)
  # a = Tensor.random(0.0...10.0, [3, 3])
  # a.matmul(a)
  #
  # # [[28.2001, 87.4285, 30.5423],
  # #  [12.4381, 30.9552, 26.2495],
  # #  [34.0873, 73.5366, 40.5504]]
  # ```
  def matmul(other : Tensor(T))
    self.assert_matrix
    other.assert_matrix

    a = @flags.contiguous? || @flags.fortran? ? self : self.dup(Num::RowMajor)
    b = other.flags.contiguous? || flags.fortran? ? other : other.dup(Num::RowMajor)
    m = a.shape[0]
    n = b.shape[1]
    k = a.shape[1]
    lda = a.flags.contiguous? ? a.shape[1] : a.shape[0]
    ldb = b.flags.contiguous? ? b.shape[1] : b.shape[0]
    dest = Tensor(T).new([m, n])
    a_trans = flags.contiguous? ? LibCblas::CblasTranspose::CblasNoTrans : LibCblas::CblasTranspose::CblasTrans
    b_trans = other.flags.contiguous? ? LibCblas::CblasTranspose::CblasNoTrans : LibCblas::CblasTranspose::CblasTrans
    blas(
      ge,
      mm,
      a_trans,
      b_trans,
      m,
      n,
      k,
      blas_const(1.0),
      a.to_unsafe,
      lda,
      b.to_unsafe,
      ldb,
      blas_const(0.0),
      dest.to_unsafe,
      dest.shape[1]
    )
    dest
  end

  # :nodoc:
  private def is_matrix
    unless self.rank == 2
      raise Exception.new
    end
  end

  # :nodoc:
  private def is_square_matrix
    unless self.rank == 2 && @shape[0] == @shape[1]
      raise Exception.new
    end
  end

  # :nodoc:
  private def assert_fortran
    unless @flags.fortran?
      raise Exception.new
    end
  end
end
