use proc_macro::TokenStream;
use quote::quote;
use syn::{DeriveInput, parse_macro_input};

/// Signal derive macro generating an impl of the [`Signal`] trait.
///
/// The trait is implemented using the module path and the name of the type.
#[proc_macro_derive(Signal)]
pub fn derive_signal(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);

    let (impl_generics, ty_generics, where_clause) = input.generics.split_for_impl();
    let name = input.ident;

    let expanded = quote! {
        impl #impl_generics Signal for #name #ty_generics #where_clause {
            fn signal_name() -> & 'static str {
                concat!(module_path!(), "::", stringify!(#name))
            }
        }
    };

    expanded.into()
}

//TODO: Implaement derive for Emitter.
